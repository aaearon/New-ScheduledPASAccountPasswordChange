#Requires -Module psPAS
function New-ScheduledPASAccountPasswordChange {
    [CmdletBinding()]
    param (
        # ID of the account that will have it's password changed
        [Parameter(
            Mandatory = $True
        )]
        [string]
        $AccountId,

        # Future password value
        [Parameter(AttributeValues)]
        [securestring]
        $Password,

        # Parameter help description
        [Parameter(AttributeValues)]
        [datetime]
        $ChangeTime
    )

    begin {

    }

    process {
        # Per scheduled password change we create a temporary working directory per 'job'
        # as we need to store the script that will be invoked and the future password
        # object in the encrypted cli xml.
        $WorkingDirectory = New-TemporaryDirectory
        # Copy the change script to the working directory
        Copy-Item -Path "$PSScriptRoot/Invoke-PASAccountPasswordChange.ps1" -Destination $WorkingDirectory
        # Export the future password as an encrypted object to the working directory
        # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-clixml?view=powershell-5.1#example-3--encrypt-an-exported-credential-object
        $CredentialFilePath = "$WorkingDirectory/ChangeTask.ps1.pscredential"
        $Password | Export-Clixml $CredentialFilePath

        # Create scheduled task
        $ChangeTaskScriptBlock = "PowerShell.exe -C ./$WorkingDirectory/Invoke-PASAccountPasswordChange.ps1 -AccountId $AccountId -NewPasswordClixmlPath $CredentialFilePath -AppId windowsScript C:\Program Files (x86)\CyberArk\ApplicationPasswordSdk\CLIPasswordSDK.exe -UserName serviceAccount01 -Address iosharp.lab -Safe Windows -PVWAAddress https://comp01/PasswordVault"
        $ScheduledTaskAction = New-ScheduledTaskAction -Execute $ChangeTaskScriptBlock
        $ScheduledTaskTrigger = New-ScheduledTaskTrigger -At $ChangeTime
        $ScheduledTaskPrincipal = New-ScheduledTaskPrincipal -UserId [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $ScheduledTask = New-ScheduledTask -Action $ScheduledTaskAction -Trigger $ScheduledTaskTrigger -Principal $ScheduledTaskPrincipal

        Register-ScheduledTask "Password Change for $AccountId" -InputObject $ScheduledTask
    }

    end {

    }
}

# https://stackoverflow.com/a/34559554
function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}