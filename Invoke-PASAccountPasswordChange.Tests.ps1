BeforeAll {
    . $PSScriptRoot/Invoke-PASAccountPasswordChange.ps1

    $AAMClientPath = 'C:\Program Files (x86)\CyberArk\ApplicationPasswordSdk\CLIPasswordSDK.exe'
    $AppID = 'windowsScript'
    $CredentialClixmlPath = 'TestDrive:\Credential.ps1.credential'

    New-Object System.Management.Automation.PSCredential("DemoUser", ('DemoPass' | ConvertTo-SecureString -AsPlainText -Force)) | Export-Clixml -Path $CredentialClixmlPath
}

Describe "Invoke-PASAccountPasswordChange" {
    It "invokes an immediate password change" {
        Mock Test-Path -MockWith { return $True } -ModuleName CredentialRetriever
        Mock Get-AIMCredential -MockWith {
            $OutputObject = [PSCustomObject]@{
                Password = 'DemoPass'
                UserName = 'DemoUser'
                Address  = 'DOMAIN.COM'
            }
            $OutputObject | Add-Member -MemberType ScriptMethod -Name ToSecureString -Value {
                $this.Password | ConvertTo-SecureString -AsPlainText -Force
            } -Force

            $OutputObject | Add-Member -MemberType ScriptMethod -Name ToCredential -Value {
                New-Object System.Management.Automation.PSCredential($this.UserName, $this.ToSecureString())
            } -Force
            return $OutputObject
        }
        Mock New-PASSession -MockWith {}
        Mock Close-PASSession -MockWith {}
        Mock Invoke-PASCPMOperation -MockWith {}

        Invoke-PASAccountPasswordChange -AccountId 1_1 -AAMClientPath $AAMClientPath -AppID $AppID -PVWAAddress https://comp01 -NewPasswordClixmlPath $CredentialClixmlPath

        Should -Invoke -CommandName Invoke-PASCPMOperation -ParameterFilter { $ChangeImmediately -eq $true -and $ChangeTask}
    }
}