#Requires -Module psPAS
#Requires -Module CredentialRetriever
function Invoke-PASAccountPasswordChange {
    param (
        [string]$NewPasswordClixmlPath,
        [string]$AccountId,
        [string]$AppID,
        [string]$AAMClientPath,
        [string]$Safe,
        [string]$UserName,
        [string]$Address,
        [string]$PVWAAddress
    )

    Set-AIMConfiguration -ClientPath $AAMClientPath
    $ApiCredential = Get-AIMCredential -AppID $AppID -Safe $Safe -UserName $UserName -Address $Address
    $ApiCredential = $ApiCredential.ToCredential()

    New-PASSession -BaseURI $PVWAAddress -type CyberArk -Credential $ApiCredential -concurrentSession $true
    $NewPassword = Import-Clixml $NewPasswordClixmlPath
    Invoke-PASCPMOperation -AccountID $AccountId -ChangeImmediately $true -NewCredentials $NewPassword
    Close-PASSession
}