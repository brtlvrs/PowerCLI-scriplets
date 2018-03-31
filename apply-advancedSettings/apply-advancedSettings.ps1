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


    #-- load functions
    import-module $scriptpath\functions\functions.psm1 #-- the module scans the functions subfolder and loads them as functions
    #-- add code to execute during exit script. Removing functions module
    $p.Add("cleanUpCodeOnExit",{remove-module -Name functions -Force -Confirm:$false})

#region Functions

}

End{
    $NormalExit=$true
    exit-script
}

Process{
    #-- load PowerCLI
    import-PowerCLi
    #-- Connect to vCenter
    connect-viserver $P.vCenter -ErrorVariable Err1
    if ($Err1) {
        write-host ("Failed to connect to vCenter " + $P.vcenter) -ForegroundColor Yellow
        write-host ($err1)
        exit-script
    }

    #-- User selection of VMs (using out-gridview)
    $VMs=get-vm ((get-vm | Select-Object name,@{N='Cluster';E={get-cluster -VM $_.name}},powerstate,vmhost,folder) | Out-GridView -PassThru -Title "Welke VMs voor aanpassen advanced settings ?"  ).name
   
    #-- select only VMs that are Powered Off
    $VMs=$VMs | where {$_.PowerState -eq "PoweredOff"}
    if ($vms | ?{$_.powerstate -ne "PoweredOff"}) {
        write-host "Niet alle geselecteerde VMs staan uit. Deze worden geskipped."
        $VMs   | ?{$_.powerstate -ne "PoweredOff"} | select name | ft -AutoSize
    }

    #-- set advanced settings
    $rslt=@()
    foreach ($vm in $VMs) {
        #-- walk through list of VMs
        #-- get all advanced settings
        $advSettings=Get-AdvancedSetting -Entity $VM | Group-Object -AsHashTable -Property name
        foreach ($setting in $P.vmHardening.GetEnumerator()) {
            #-- walk through all advanced settings from the parameter file
            if ($advsettings.Contains($setting.name)) {
                #-- update advanced setting
                $rslt+=Get-AdvancedSetting -Entity $VM -Name $Setting.name | Set-AdvancedSetting -Value $setting.Value -Confirm:$false | select @{N='VM';E={$VM.name}},name,value,description
            } else {
                #-- create advanced setting
                $rslt+=New-AdvancedSetting -Entity $VM -Name $setting.name -Value $setting.value -Confirm:$false| select @{N='VM';E={$VM.name}},name,value,description
            }
        }
    }
 
    #-- echo result
    $rslt | ft -AutoSize

}