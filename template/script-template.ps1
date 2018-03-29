<#
.SYNOPSIS
   synopsis of script
.DESCRIPTION
    Script description

.PARAMETER param1
    Parameter explenation

.EXAMPLE
    script examples

.NOTES
    File Name          : script-template.ps1
    Author             : B. Lievers
    Prerequisite       : PowerShell V2 over Vista and upper.
    Version            : 0.2.1
    License            : MIT License
    Copyright 2018 - Bart Lievers
#>
[CmdletBinding()]
Param(
   )


Begin{
#Parameters
    $TS_start=Get-Date #-- get start time

    #-- get script parameters
	$scriptpath=(get-item (Split-Path -parent $MyInvocation.MyCommand.Definition)).fullname
    $scriptname=Split-Path -Leaf $MyInvocation.mycommand.path
    
    #-- load default parameter
    #-- Load Parameterfile
    if (!(test-path -Path $scriptpath\parameters.ps1 -IsValid)) {
        write-warning "parameters.ps1 not found. Script will exit."
        exit
        
    }
    $P = & $scriptpath\parameters.ps1
    if ($P.ProjectIMFoldersAreSiblings) {
        $scriptpath=split-path -Path $scriptpath -Parent
    }

    # Gather all files
    $Functions  = @(Get-ChildItem -Path ($scriptpath+"\"+$P.FunctionsSubFolder) -Filter *.ps1 -ErrorAction SilentlyContinue)

    # Dot source the functions
    ForEach ($File in @($Functions)) {
        Try {
            . $File.FullName
        } Catch {
            Write-Error -Message "Failed to import function $($File.FullName): $_"
        }       
    }

#region Functions
    function exit-script {
    <#
    .DESCRIPTION
        function to exit script clean.
    #>

    [CmdletBinding()]
    Param()
    #-- disconnect vCenter connections (if there are any)
    if ((Get-Variable -Scope global -Name DefaultVIServers -ErrorAction SilentlyContinue ).value) {
        Disconnect-VIServer -server * -Confirm:$false
    }
    #-- clock time and say bye bye
    $ts_end=get-date
    if ($NormalExit) {write-host "Script ends normal."}
    else {write-host "Scripts exit is premature." -ForegroundColor Yellow}
    write-host ("Runtime script: {0:hh}:{0:mm}:{0:ss}" -f ($ts_end- $TS_start)  )
    read-host "End script. bye bye ([Enter] to quit.)"
    exit
    }
}

End{
    $NormalExit=$true
    exit-script
}

Process{
    import-module vmware.powercli
#    connect-viserver $P.vCenter -ErrorVariable Err1
    test-brtlvrs
    if ($Err1) {
        write-host ("Failed to connect to vCenter " + $P.vcenter) -ForegroundColor Yellow
        write-host ($err1)
        exit-script

    }

}