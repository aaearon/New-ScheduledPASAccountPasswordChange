# New-ScheduledPASAccountPasswordChange

Uses Windows Scheduled Tasks, AAM Credential Provider/Central Credential Provider, and Export-Clixml to schedule password changes for CyberArk-managed accounts.

## How to use

### Requirements

On the machine you are creating the Scheduled Task on:

* [psPAS](https://github.com/pspete/psPAS)
* [CredentialRetriever](https://github.com/pspete/CredentialRetriever)
* Administrator rights on the machine you are creataing the Scheduled Task on.

### Creating a Scheduled Task

1. Clone the repository to the machine you want the Scheduled Task to run on.
1. Open an elevated PowerShell prompt and run `Import-Module New-ScheduledPASAccountPasswordChange`.
1. Run `New-ScheduledPASAccountPasswordChange`

```powershell
$arguments = @{
    AccountId = '12_7'
    AppId = scheduledPasswordChangeScript
    ChangeTime = ((Get-Date) AddSeconds(5))
    PvwaAddress = 'https://comp01'
    Password = ("VeryComplex!23" | ConvertTo-SecureString -AsPlainText -Force)
    Safe = 'CyberArk'
    UserName = 'serviceAccount01'
    Address = '192.168.0.50'
    CentralCredentialProviderURL = 'https://comp01'
}

New-ScheduledPASAccountPasswordChange @arguments
```

Double check in Task Scheduler that your new Task has been created.
