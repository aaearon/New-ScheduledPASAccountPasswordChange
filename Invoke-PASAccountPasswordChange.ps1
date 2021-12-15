#Requires -Module psPAS
#Requires -Module CredentialRetriever
function Invoke-PASAccountPasswordChange {
    param (
        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$NewCredentialClixmlPath,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$AccountId,

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
        [string]$Address,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [string]$CredentialProviderPath,

        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$CentralCredentialProviderURL,

        [Parameter(ParameterSetName = 'CredentialProvider', Mandatory = $true)]
        [Parameter(ParameterSetName = 'CentralCredentialProvider', Mandatory = $true)]
        [string]$PvwaAddress
    )

    begin {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'CredentialProvider' {
                    Set-AIMConfiguration -ClientPath $CredentialProviderPath
                    $ApiCredential = Get-AIMCredential -AppID $AppID -Safe $Safe -UserName $UserName -Address $Address
                }
                'CentralCredentialProvider' {
                    $ApiCredential = Get-CCPCredential -AppID $AppID -Safe $Safe -UserName $UserName -Address $Address -URL $CentralCredentialProviderURL -SkipCertificateCheck
                }
            }
        } catch {
            Write-Error $Error
        }

        Close-PASSession
        $ApiCredential = $ApiCredential.ToCredential()
        New-PASSession -BaseURI $PvwaAddress -type CyberArk -Credential $ApiCredential -concurrentSession $true -SkipCertificateCheck
    }

    process {
        $NewCredential = Import-Clixml $NewCredentialClixmlPath
        Invoke-PASCPMOperation -AccountID $AccountId -ChangeTask -ChangeImmediately $true -NewCredentials $NewCredential.Password
    }

    end {
        Close-PASSession
    }

}