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
    File Name          : create-vmConfig.ps1
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

}

End{
    $NormalExit=$true
    exit-script
}

Process{
    import-PowerCLi
    connect-viserver $P.vCenter -ErrorVariable Err1
    if ($Err1) {
        write-host ("Failed to connect to vCenter " + $P.vcenter) -ForegroundColor Yellow
        write-host ($err1)
        exit-script
    }

    #-- load recipe
    $R= & (gci -Path $scriptpath -Filter *.recipe.ps1 | out-gridview -PassThru -Title "Select recipe to build VM from."| select -ExpandProperty fullname)
    write-host ("Recipe description: "  + $R.Description)
    #-- get VM name
    $vmName=$R.vm.name

    #-- check if VM exists
    if (get-vm $vmName -ErrorAction SilentlyContinue) {
        Do {       
            Do {
                #-- ask question with the multiple options added between brackets. Capitalized option is the default option.
                $answer=read-host ("VM $vmName exists, remove it ? [yN]")
                #-- validate answer with regex
                Switch -Regex ($answer) {
                    "\A(Y|y)\Z" {
                        #-- input is only a y or a Y
                        $loopDone=$true #-- we had a valid answer, so exit loop
                        $VM=get-vm $vmName
                        if ($VM.PowerState -ne "PoweredOff") {
                            Stop-VM -VM $VM -Confirm:$false -Kill
                        }
                        Remove-VM -VM $VM -DeletePermanently -Confirm:$false
                        break
                    }
                    "\A(n|N|)\Z" {
                        #-- input is only a n or N or nothing. \A = start of line \Z is end of the line==> \A\Z = nothing returned = empty answer
                        $loopdone=$true
                        $vmName = read-host ("VM $vmName exists, please enter new name")
                        break
                    }
                    default {
                        #-- the default action, no valid input
                        $loopdone=$false
                        write-host "Unknown answer."
                    }
                }
               } until ($loopDone)
            #-- end DO when VM doesn't exist
            $exitLoop= (get-vm $vmName -ErrorAction SilentlyContinue).count -eq 0 # VM name doesn't exist
        } until ($exitLoop)
    }

    #-- create new VM
    #-- add vmhost and datastore to config
    $R.vm.add('vmhost',(get-vmhost | Out-GridView -PassThru -Title "Select vmHost to create VM on"))
    $R.vm.add('datastore',($R.vm.vmhost | get-datastore | Out-GridView -PassThru -Title "Welke datastore ?"))

    if (($R.vm.vmhost | Get-Cluster).DrsEnabled -eq $false) {
        $R.vm.Remove("DrsAutomationLevel")
    }
        if (($R.vm.vmhost | Get-Cluster).HAEnabled -eq $false) {
        $R.vm.Remove("HARestartPriority")
        $R.vm.Remove("HAIsolationResponse")
    }
    write-host "create VM"
    $param=$R.VM
    $VM= new-vm @param

    #-- add disks, first disk is already added
    write-host "Adding disks"
    foreach ($disk in ($R.vmdk.GetEnumerator() | sort name | ?{$_.name -ilike "disk*"})) {
        $param=$disk.value
        New-HardDisk -VM $VM @param | out-null
    }

    #-- network
    write-host "Configuring ethernet adapters"
    if ($R.network.count -gt 0) {
        $VM | Get-NetworkAdapter | Remove-NetworkAdapter -confirm:$false | out-null
        foreach ($nic in $R.network.GetEnumerator()) {
        $param=$nic.Value
        $VM | New-NetworkAdapter @param    | out-null
        }       
    }

    #-- set advanced settings VM
    write-host "Configuring advanced settings"
    foreach ($setting in $R.advSetting.GetEnumerator()) {
        $advSetting=Get-AdvancedSetting -Entity $VM -Name $setting.key
        if ($advSetting) { 
            $advSetting | Set-AdvancedSetting -Value $settings.value | out-null}
        else {
            New-AdvancedSetting -Entity $VM -Name $setting.key -Value $setting.value -Confirm:$false | out-null
            }
    }
}