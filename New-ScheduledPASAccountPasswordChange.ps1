#Requires -Module psPAS
function New-ScheduledPASAccountPasswordChange {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$AccountId,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [securestring]$Password,

        # Parameter help description
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [datetime]$ChangeTime,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$PvwaAddress,

        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$CentralCredentialProviderURL,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [string]$CredentialProviderPath,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$AppID,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$Safe,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$UserName,

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
        # PSCredential object so we need to convert the password as secure string to a PSCredential
        $PasswordCredentialObject = New-Object System.Management.Automation.PSCredential("dummydata", $Password)
        $PasswordCredentialObject | Export-Clixml $CredentialFilePath

        # Create scheduled task
        switch ($PSCmdlet.ParameterSetName) {
            'CredentialProvider' {
                $ChangeTaskScriptBlock = "{Import-Module $WorkingDirectory\Invoke-PASAccountPasswordChange.ps1; Invoke-PASAccountPasswordChange -AccountId $AccountId -NewCredentialClixmlPath $CredentialFilePath -PVWAAddress $PvwaAddress -AppID $AppID -UserName $UserName -Address $Address -Safe $Safe -CredentialProviderPath $CredentialProviderPath}"
            }

            'CentralCredentialProvider' {
                $ChangeTaskScriptBlock = "{Import-Module $WorkingDirectory\Invoke-PASAccountPasswordChange.ps1; Invoke-PASAccountPasswordChange -AccountId $AccountId -NewCredentialClixmlPath $CredentialFilePath -PVWAAddress $PvwaAddress -AppID $AppID -UserName $UserName -Address $Address -Safe $Safe -CentralCredentialProviderURL $CentralCredentialProviderURL}"
            }
        }

        $ScheduledTaskAction = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command % `"$ChangeTaskScriptBlock`""
        $ScheduledTaskTrigger = New-ScheduledTaskTrigger -At $ChangeTime -Once
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