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
    $TS_start=Get-Date #-- get start time of script. Used in exit-script function to determine script execution time.

    #-- get script parameters
	$scriptpath=(get-item (Split-Path -parent $MyInvocation.MyCommand.Definition)).fullname
    $scriptname=Split-Path -Leaf $MyInvocation.mycommand.path
    
    #-- Load Parameterfile
    if (!(test-path -Path $scriptpath\parameters.ps1 -IsValid)) {
        write-warning "parameters.ps1 not found. Script will exit."
        exit   
    }
    $P = & $scriptpath\parameters.ps1
    if ($P.ProjectIMFoldersAreSiblings) {
        $scriptpath=split-path -Path $scriptpath -Parent
    }

    #-- load functions
    import-module $scriptpath\functions\functions.psm1 #-- the module scans the functions subfolder and loads them as functions
    #-- add code to execute during exit script. Removing functions module
    $p.Add("cleanUpCodeOnExit",{remove-module -Name functions -Force -Confirm:$false})
}

End{
    $finished_normal=$true #-- to tell exit-script then we finished the script without script errors
    exit-script
}

Process{
    import-module vmware.powercli -ErrorAction SilentlyContinue -ErrorVariable Err1
    if ($Err1) {
        write-host ("Failed to load PowerCLI.") -ForegroundColor Yellow
        write-host ($err1)
        exit-script
    }

}