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
       Loading of all VMware modules and power snapins
    .DESCRIPTION

    .EXAMPLE
        One or more examples for how to use this script
    .NOTES
        File Name          : import-PowerCLI.ps1
        Author             : Bart Lievers
        Prerequisite       : <Preruiqisites like
                             Min. PowerShell version : 2.0
                             PS Modules and version :
                                PowerCLI - 5.5
        Last Edit          : BL - 22-11-2016
    #>
    [CmdletBinding()]

    Param(
    )

    Begin{

    }

    Process{
        #-- make up inventory and check PowerCLI installation
        $RegisteredModules=Get-Module -Name vmware* -ListAvailable -ErrorAction ignore | % {$_.Name}
        $RegisteredSnapins=get-pssnapin -Registered vmware* -ErrorAction Ignore | %{$_.name}
        if (($RegisteredModules.Count -eq 0 ) -and ($RegisteredSnapins.count -eq 0 )) {
            #-- PowerCLI is not installed
            if ($log) {$log.warning("Cannot load PowerCLI, no VMware Powercli Modules and/or Snapins found.")}
            else {
            write-warning "Cannot load PowerCLI, no VMware Powercli Modules and/or Snapins found."}
            #-- exit function
            return $false
        }

        #-- load modules
        if ($RegisteredModules) {
            #-- make inventory of already loaded VMware modules
            $loaded = Get-Module -Name vmware* -ErrorAction Ignore | % {$_.Name}
            #-- make inventory of available VMware modules
            $registered = Get-Module -Name vmware* -ListAvailable -ErrorAction Ignore | % {$_.Name}
            #-- determine which modules needs to be loaded, and import them.
            $notLoaded = $registered | ? {$loaded -notcontains $_}

            foreach ($module in $registered) {
                if ($loaded -notcontains $module) {
                    Import-Module $module
                }
            }
        }

        #-- load Snapins
        if ($RegisteredSnapins) {      
            #-- Exlude loaded modules from additional snappins to load
            $snapinList=Compare-Object -ReferenceObject $RegisteredModules -DifferenceObject $RegisteredSnapins | ?{$_.sideindicator -eq "=>"} | %{$_.inputobject}
            #-- Make inventory of loaded VMware Snapins
            $loaded = Get-PSSnapin -Name $snapinList -ErrorAction Ignore | % {$_.Name}
            #-- Make inventory of VMware Snapins that are registered
            $registered = Get-PSSnapin -Name $snapinList -Registered -ErrorAction Ignore  | % {$_.Name}
            #-- determine which snapins needs to loaded, and import them.
            $notLoaded = $registered | ? {$loaded -notcontains $_}

            foreach ($snapin in $registered) {
                if ($loaded -notcontains $snapin) {
                    Add-PSSnapin $snapin
                }
            }
        }
        #-- show loaded vmware modules and snapins
        if ($RegisteredModules) {get-module -Name vmware* | select name,version,@{N="type";E={"module"}} | ft -AutoSize}
          if ($RegisteredSnapins) {get-pssnapin -Name vmware* | select name,version,@{N="type";E={"snapin"}} | ft -AutoSize}

    }

    End{

    }

    }

    function Ask-yesNo {
        [CmdletBinding()]
        param(
            [string]$question,
            [scriptblock]$codeY,
            [scriptblock]$codeN
        )

        Do {
            $answer=read-host ($question + "? [yN]")
            Switch -Regex ($answer) {
                "\A(Y|y)\Z" {
                    #-- input is only a y or a Y
                    $loopDone=$true #-- we had a valid answer, so exit loop
                    & $codeY
                    break
                }
                "\A(n|N|)\Z" {
                    #-- input is only a n or N or nothing. \A = start of line \Z is end of the line==> \A\Z = nothing returned = empty answer
                    $loopdone=$true
                    & $codeN
                    break
                }
                default {
                    #-- the default action, no valid input
                    $loopdone=$false
                    write-host "Unknown answer."
                }
            }
        } until ($loopDone)
        Return $answer

    }
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