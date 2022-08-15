#Requires -Module psPAS
function New-ScheduledPASAccountPasswordChange {
    <#
    .SYNOPSIS
        Creates a Scheduled Task that will execute a script at a specific time to change an account's password.
    .DESCRIPTION
        Using Windows Scheduled Tasks, this PowerShell script will create a Scheduled Task that runs at a specific time and will execute a script to change the provided account's password. The password is stored as
        an exported credential object.
    .EXAMPLE
        PS C:\> New-ScheduledPASAccountPasswordChange -AccountId 12_7 -AppID scheduledPasswordChangeScript -ChangeTime ((Get-Date) AddDays(5)) -PvwaAddress https://comp01 -Password ("VeryComplex!23" | ConvertTo-SecureString -AsPlainText -Force) -Safe CyberArk -UserName serviceAccount01 -Address 192.168.0.50 -CentralCredentialProviderURL https://comp01
        For the account with the id of 12_7, a Scheduled Task is created to execute a password change 5 days from now to the value "VeryComplex!23". The Central Credential Provider is leveraged to pull the password for the service account that will authenticate to the CyberArk PVWA (https://comp01) and perform the change.
    #>
    [CmdletBinding()]
    param (
        # The id of the account (i.e 12_6)
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$AccountId,

        # The future password as a secure string.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [securestring]$Password,

        # The date and time the password should be changed. The Scheduled Task will run at this time.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [datetime]$ChangeTime,

        # The address of the PVWA for the environment the account resides in.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$PvwaAddress,

        # The URL of the Central Credential Provider instance. The password for the service account that will be used to execute the password change will be retrieved from here.
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$CentralCredentialProviderURL,

        # The full path of where the locally installed Credential Provider agent is installed. The password for the service account that will be used to execute the password change will be retrieved using the CP installed here.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [string]$CredentialProviderPath,

        # The AppID to authenticate to the Credential Provider or Central Credential Provider with. The AppID should have the needed authorizations to get the password for the serivce account performing the change.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$AppID,

        # The safe where the service account that will be used to perform the password change is stored.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$Safe,

        # The username of the service account that will be used to perform the password change.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$UserName,

        # The address of the service account that will be used to perform the password change.
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$Address
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
        $CredentialFilePath = "$WorkingDirectory/Invoke-PASAccountPasswordChange.ps1.pscredential"
        # When wanting to save soemthing encrypted, Export-Clixml seems to expect that the input
        # PSCredential object so we need to convert the password from the provided secure string to a PSCredential
        $PasswordCredentialObject = New-Object System.Management.Automation.PSCredential('dummydata', $Password)
        $PasswordCredentialObject | Export-Clixml $CredentialFilePath

        ## Create scheduled task
        # The script that will perform the password change is called.
        switch ($PSCmdlet.ParameterSetName) {
            'CredentialProvider' {
                $Provider = "-CredentialProviderPath $CredentialProviderPath}"
            }

            'CentralCredentialProvider' {
                $Provider = "-CentralCredentialProviderURL $CentralCredentialProviderURL}"
            }
        }
        $ChangeTaskScriptBlock = "{Import-Module $WorkingDirectory\Invoke-PASAccountPasswordChange.ps1; Invoke-PASAccountPasswordChange -AccountId $AccountId -NewCredentialClixmlPath $CredentialFilePath -PVWAAddress $PvwaAddress -AppID $AppID -UserName $UserName -Address $Address -Safe $Safe $Provider"

        $ScheduledTaskAction = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command % `"$ChangeTaskScriptBlock`""
        $ScheduledTaskTrigger = New-ScheduledTaskTrigger -At $ChangeTime -Once
        # The scheduled task needs to run under the same user that creates the Export-Clixml as Windows
        # Data Protection API's encryption 'that only your user account on only that computer can decrypt
        # the contents of the credential object' (see above link)
        $ScheduledTaskPrincipal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType S4U -RunLevel Limited
        $ScheduledTaskSettings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
        $ScheduledTask = New-ScheduledTask -Action $ScheduledTaskAction -Trigger $ScheduledTaskTrigger -Principal $ScheduledTaskPrincipal -Settings $ScheduledTaskSettings

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