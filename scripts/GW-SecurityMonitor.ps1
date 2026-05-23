<#
.SYNOPSIS
    Monitors the Windows Security event log for high-priority identity events.

.DESCRIPTION
    Queries the last 24 hours of the Security event log for key identity-related
    event IDs. Exports findings to CSV and displays results in console.

    Monitored Event IDs:
    4625 - Failed logon attempt
    4648 - Explicit credential logon (potential pass-the-hash or scheduled task)
    4720 - User account created
    4726 - User account deleted
    4728 - Member added to security-enabled global group
    4756 - Member added to security-enabled universal group

.EXAMPLE
    .\GW-SecurityMonitor.ps1
#>

$events = @{
    4625 = "Failed Logon"
    4648 = "Explicit Credential Logon"
    4720 = "User Account Created"
    4726 = "User Account Deleted"
    4728 = "Member Added to Security Group"
    4756 = "Member Added to Universal Group"
}

$report = @()
$since = (Get-Date).AddHours(-24)

foreach ($id in $events.Keys) {
    $found = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        Id        = $id
        StartTime = $since
    } -ErrorAction SilentlyContinue

    foreach ($e in $found) {
        $report += [PSCustomObject]@{
            TimeCreated = $e.TimeCreated
            EventID     = $id
            Description = $events[$id]
            Message     = $e.Message.Split("`n")[0]
        }
    }
}

$reportPath = "C:\GoldenWorks\Reports\SecurityMonitor-$(Get-Date -Format 'yyyy-MM-dd-HHmm').csv"
$report | Export-Csv -Path $reportPath -NoTypeInformation

Write-Host "Security monitor complete. $($report.Count) events found in last 24 hours." -ForegroundColor Cyan
$report | Sort-Object TimeCreated -Descending | Format-Table -AutoSize
