<#
.SYNOPSIS
    Performs a quarterly access review for GoldenWorks Labs AD environment.

.DESCRIPTION
    Detects three categories of identity governance issues:
    1. Stale accounts - enabled but no logon in 90+ days
    2. Never-logged-in accounts - created 30+ days ago with no logon
    3. Disabled accounts still holding group memberships

    Exports findings to CSV in C:\GoldenWorks\Reports\

.EXAMPLE
    .\GW-AccessReview.ps1
#>

$report = @()
$cutoff = (Get-Date).AddDays(-90)

# Stale accounts
$staleUsers = Get-ADUser -Filter {Enabled -eq $true -and LastLogonDate -lt $cutoff} `
    -Properties LastLogonDate, Department, Title |
    Where-Object { $_.LastLogonDate -ne $null }

foreach ($u in $staleUsers) {
    $report += [PSCustomObject]@{
        SamAccountName = $u.SamAccountName
        Name           = $u.Name
        Department     = $u.Department
        LastLogon      = $u.LastLogonDate
        Issue          = "Stale - No logon in 90+ days"
        Action         = "Review for disable"
    }
}

# Accounts never logged in
$neverLogon = Get-ADUser -Filter {Enabled -eq $true -and LastLogonDate -notlike "*"} `
    -Properties LastLogonDate, Department, WhenCreated |
    Where-Object { $_.WhenCreated -lt (Get-Date).AddDays(-30) }

foreach ($u in $neverLogon) {
    $report += [PSCustomObject]@{
        SamAccountName = $u.SamAccountName
        Name           = $u.Name
        Department     = $u.Department
        LastLogon      = "Never"
        Issue          = "Never logged in - account older than 30 days"
        Action         = "Verify with manager or disable"
    }
}

# Disabled users still in security groups
$disabledWithGroups = Get-ADUser -Filter {Enabled -eq $false} -Properties MemberOf, Department |
    Where-Object { $_.MemberOf.Count -gt 0 }

foreach ($u in $disabledWithGroups) {
    $report += [PSCustomObject]@{
        SamAccountName = $u.SamAccountName
        Name           = $u.Name
        Department     = $u.Department
        LastLogon      = "Disabled"
        Issue          = "Disabled account still has group memberships"
        Action         = "Remove from all groups"
    }
}

$reportPath = "C:\GoldenWorks\Reports\AccessReview-$(Get-Date -Format 'yyyy-MM-dd').csv"
New-Item -ItemType Directory -Path "C:\GoldenWorks\Reports" -Force | Out-Null
$report | Export-Csv -Path $reportPath -NoTypeInformation

Write-Host "Access review complete. $($report.Count) issues found." -ForegroundColor Yellow
Write-Host "Report saved to $reportPath" -ForegroundColor Cyan
$report | Format-Table -AutoSize
