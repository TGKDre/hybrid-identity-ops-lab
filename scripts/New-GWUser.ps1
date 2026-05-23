<#
.SYNOPSIS
    Onboards a new GoldenWorks Labs employee into Active Directory.

.DESCRIPTION
    Creates a new AD user account with correct OU placement, department group
    assignment, VPN group assignment, and forced password reset at first logon.

.PARAMETER FirstName
    Employee first name.

.PARAMETER LastName
    Employee last name.

.PARAMETER Department
    Employee department (used for description and group assignment).

.PARAMETER Title
    Employee job title.

.PARAMETER Team
    Team assignment. Valid values: IT, Security, HR, Finance.

.EXAMPLE
    .\New-GWUser.ps1 -FirstName "Jane" -LastName "Doe" -Department "Security" -Title "SOC Analyst" -Team "Security"
#>
param(
    [Parameter(Mandatory)][string]$FirstName,
    [Parameter(Mandatory)][string]$LastName,
    [Parameter(Mandatory)][string]$Department,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][ValidateSet("IT","Security","HR","Finance")][string]$Team
)

$SamAccountName = ($FirstName[0] + $LastName).ToLower()
$UPN = "$SamAccountName@goldenworkslabs.local"
$Password = ConvertTo-SecureString "Welcome12345678!" -AsPlainText -Force
$UserOU = "OU=Users,OU=GoldenWorks,DC=goldenworkslabs,DC=local"

$groupMap = @{
    "IT"       = "GW-IT-Staff"
    "Security" = "GW-Security-Team"
    "HR"       = "GW-HR-Staff"
    "Finance"  = "GW-Finance-Staff"
}

New-ADUser -Name "$FirstName $LastName" `
    -SamAccountName $SamAccountName `
    -UserPrincipalName $UPN `
    -GivenName $FirstName `
    -Surname $LastName `
    -Title $Title `
    -Department $Department `
    -Path $UserOU `
    -AccountPassword $Password `
    -Enabled $true `
    -ChangePasswordAtLogon $true

Add-ADGroupMember -Identity $groupMap[$Team] -Members $SamAccountName
Add-ADGroupMember -Identity "GW-VPN-Users" -Members $SamAccountName

Write-Host "User $SamAccountName created and added to $($groupMap[$Team]) and GW-VPN-Users" -ForegroundColor Green
Write-Host "Ticket closed. Onboarding complete for $FirstName $LastName" -ForegroundColor Cyan
