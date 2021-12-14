BeforeAll {
    . $PSScriptRoot/Invoke-PASAccountPasswordChange.ps1

    $AAMClientPath = 'C:\Program Files (x86)\CyberArk\ApplicationPasswordSdk\CLIPasswordSDK.exe'
    $AppID = 'windowsScript'
    $CredentialClixmlPath = TestDrive:\Credential.ps1.credential
    "Example" | Export-Clixml -Path $CredentialClixmlPath
}

Describe "Invoke-PASAccountPasswordChange" {
    It "invokes an immediate password change" {
        Mock Invoke-PASCPMOperation -MockWith {} -ModuleName psPAS

        Invoke-PASAccountPasswordChange -AccountId 1_1 -AAMClientPath $AAMClientPath -AppID $AppID

        Should -Invoke -CommandName Invoke-PASCPMOperation -ParameterFilter {$ChangeImmediate -eq $true}
    }
}