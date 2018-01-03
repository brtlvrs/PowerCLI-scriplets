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

    #-- Select VMs
    $VMs=get-vm ((get-vm | Select-Object name,@{N='Cluster';E={get-cluster -VM $_.name}},powerstate,vmhost,folder) | Out-GridView -PassThru -Title "Welke VMs voor aanpassen advanced settings ?"  ).name
    $VMsGrouped=$VMs | Group-Object -Property Powerstate
   
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