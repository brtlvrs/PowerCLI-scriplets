﻿<#
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

    #-- initialize variables

#region Functions

    function exit-script {
        <#
        .DESCRIPTION
            function to exit script clean.
        #>

        [CmdletBinding()]
        Param()

        #-- disconnect vCenter connections (if there are any)
        if (((Get-Variable -Scope global -Name DefaultVIServers -ErrorAction SilentlyContinue ).value) -and ($P.noDisconnectOnExit -eq $false)) {
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

    function import-PowerCLi {
    <#
    .SYNOPSIS
       Loading of all VMware modules
    #>
        [CmdletBinding()]
        Param()
        Process{
            #-- check if PowerCLI is installed
            if ((get-module -ListAvailable vmware*).count -lt 1) {
                write-host "VMware PowerCLI modules not found."
                exit-script
            }
            #-- Load all modules
            get-module -ListAvailable vmware* | Import-Module
        }
    }
    
    #endregion
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

    #-- get VM name
    $vmName=$p.recipe.vm.name

    #-- check if VM exists
    if (get-vm $vmName) {
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
            $exitLoop= (get-vm $vmName).count -eq 0 # VM name doesn't exist
        } until ($exitLoop)
    }

    #-- create new VM
    #-- add vmhost and datastore to config
    $p.recipe.vm.add('vmhost',(get-vmhost | Out-GridView -PassThru -Title "Select vmHost to create VM on"))
    $p.recipe.vm.add('datastore',($vmhost | get-datastore | Out-GridView -PassThru -Title "Welke datastore ?"))
    $param=$p.recipe.VM
    $VM= new-vm @param

    #-- add disks, first disk is already added
    foreach ($disk in ($p.recipe.vmdk.GetEnumerator() | sort name | ?{$_.name -ilike "disk*"})) {
        $param=$disk.value
        New-HardDisk -VM $VM @param    
    }

    #-- network
    if ($P.recipe.network.count -gt 0) {
        $VM | Get-NetworkAdapter | Remove-NetworkAdapter -confirm:$false
        foreach ($nic in $P.recipe.network.GetEnumerator()) {
        $param=$nic.Value
        $VM | New-NetworkAdapter @param    
        }       
    }
#    $param=$p.recipe.nic

  #  $VM | Get-NetworkAdapter | Remove-NetworkAdapter -confirm:$false
   # $VM | New-NetworkAdapter @param 

    #-- set advanced settings VM
    foreach ($setting in $p.recipe.advSetting.GetEnumerator()) {
        if (Get-AdvancedSetting -Entity $VM -Name $setting.key) { 
            Get-AdvancedSetting -Entity $VM -Name $setting.key | Set-AdvancedSetting -Value $settings.value}
        else {
            New-AdvancedSetting -Entity $VM -Name $setting.key -Value $setting.value -Confirm:$false
            }
    }
}