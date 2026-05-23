<#
.SYNOPSIS
    Offboards a GoldenWorks Labs employee from Active Directory.

.DESCRIPTION
    Disables the user account, removes all group memberships, moves the account
    to the Disabled OU, and renames it with the associated ticket number for
    audit trail purposes.

.PARAMETER SamAccountName
    The sAMAccountName of the user to offboard.

.PARAMETER TicketNumber
    The incident or service request ticket number associated with this offboarding.

.EXAMPLE
    .\Remove-GWUser.ps1 -SamAccountName "jdoe" -TicketNumber "INC-00421"
#>
param(
    [Parameter(Mandatory)][string]$SamAccountName,
    [Parameter(Mandatory)][string]$TicketNumber
)

$DisabledOU = "OU=Disabled,OU=GoldenWorks,DC=goldenworkslabs,DC=local"
$user = Get-ADUser -Identity $SamAccountName -Properties MemberOf

# Disable account
Disable-ADAccount -Identity $SamAccountName

# Remove all group memberships
foreach ($group in $user.MemberOf) {
    Remove-ADGroupMember -Identity $group -Members $SamAccountName -Confirm:$false
}

# Move to Disabled OU
Move-ADObject -Identity $user.DistinguishedName -TargetPath $DisabledOU

# Rename with ticket reference
Rename-ADObject -Identity (Get-ADUser $SamAccountName).DistinguishedName `
    -NewName "DISABLED-$TicketNumber-$SamAccountName"

Write-Host "User $SamAccountName disabled, groups removed, moved to Disabled OU" -ForegroundColor Yellow
Write-Host "Ticket $TicketNumber offboarding complete." -ForegroundColor Cyan
