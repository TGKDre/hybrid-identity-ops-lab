<#
.SYNOPSIS
    Remediates disabled AD accounts that still hold group memberships.

.DESCRIPTION
    Automatically removes group memberships from disabled accounts.
    Excludes sensitive built-in accounts: krbtgt, Guest, Administrator.
    Safe to run on a schedule as part of automated governance.

.EXAMPLE
    .\GW-Remediate-DisabledGroups.ps1
#>

$excluded = @("krbtgt", "Guest", "Administrator")

$disabledWithGroups = Get-ADUser -Filter {Enabled -eq $false} -Properties MemberOf |
    Where-Object { $_.MemberOf.Count -gt 0 -and $_.SamAccountName -notin $excluded }

if ($disabledWithGroups.Count -eq 0) {
    Write-Host "No remediation needed. All disabled accounts are clean." -ForegroundColor Green
    exit
}

foreach ($u in $disabledWithGroups) {
    foreach ($group in $u.MemberOf) {
        Remove-ADGroupMember -Identity $group -Members $u.SamAccountName -Confirm:$false
        Write-Host "Removed $($u.SamAccountName) from $group" -ForegroundColor Yellow
    }
    Write-Host "Remediation complete for $($u.SamAccountName)" -ForegroundColor Cyan
}
