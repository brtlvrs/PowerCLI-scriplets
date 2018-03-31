<#
.SYNOPSIS
   Register .vmx files to vCenter
.DESCRIPTION
   Register .vmx files to vCenter
.EXAMPLE
    One or more examples for how to use this script
.NOTES
    File Name          : register-VMsByDatastores.ps1
    Author             : Bart Lievers
    version            : develop/v0.0.5
    Prerequisite       : Powershell >= v 3.0
                         PowerCLI >= 5.8
    Copyright 2015 - CAM IT Solutions
#>

[CmdletBinding()]

Param(
)

Begin{
    #-- initialize environment
    $DebugPreference="SilentlyContinue"
    $VerbosePreference="SilentlyContinue"
    $ErrorActionPreference="Continue"
    $WarningPreference="Continue"
    clear-host #-- clear CLi
    $ts_start=get-date #-- note start time of script
    if ($finished_normal) {Remove-Variable -Name finished_normal -Confirm:$false }

	#-- determine script location and name
	$scriptpath=get-item (Split-Path -parent $MyInvocation.MyCommand.Definition)
	$scriptname=(Split-Path -Leaf $MyInvocation.mycommand.path).Split(".")[0]

    #-- Load Parameterfile
    if (!(test-path -Path $scriptpath\parameters.ps1 -IsValid)) {
        write-warning "parameters.ps1 niet gevonden. Script kan niet verder."
        exit
    } 
    $P = & $scriptpath\parameters.ps1

    #-- load functions
    import-module $scriptpath\functions\functions.psm1 #-- the module scans the functions subfolder and loads them as functions
    #-- add code to execute during exit script. Removing functions module
    $p.Add("cleanUpCodeOnExit",{remove-module -Name functions -Force -Confirm:$false})

#region for Private script functions
    #-- note: place any specific function in this region

#endregion
}

Process{

    import-powercli
    connect-viserver $P.vcenter -ErrorAction SilentlyContinue -ErrorVariable Err1
    if ($err1) {
        write-warning ("Geen verbinding kunnen maken met "+($p.vCenter))
        exit-script
    }

    # Select datastore and VM Folder interactivly
    $Datastore = get-datastore | sort-object name | Out-GridView -Title "Selecteer de datastore." -OutputMode Single
    if ($datastore.length -le 0) {
        write-warning "Geen datastore geselecteerd."
        exit-script
    }
    $VMFolder = get-folder | ? {$_.Type -imatch "VM"} | select name,parent | sort-object name | Out-GridView -Title "Select Folder" -OutputMode Single | select -ExpandProperty name
    if ($vmFolder.length -le 0) {
        Write-Warning "Geen VM Folder geselecteerd."
        exit-script
    }

    #-- select vSphere ESXi host where datastore is mounted to register VMs on
    $ESXhost = Get-Datastore $datastore | get-vmhost | select -first 1 -ExpandProperty name
    write-host "Selected $ESXhost to register VMs on."
    #build table containing all registed VMs
    $knownVMTable = get-vm | select name | Group-Object -AsHashTable -Property name
 
    $tasklist=@{}

    foreach($Datastore in $Datastore) {
        # Searches for .VMX Files in datastore variable
        $ds = Get-Datastore -Name $Datastore | %{Get-View $_.Id}
        $SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
        $SearchSpec.matchpattern = "*.vmx"
        $dsBrowser = Get-View $ds.browser
        $DatastorePath = "[" + $ds.Summary.Name + "]"
 
        # Find all .VMX file paths in Datastore variable and filters out .snapshot
        $SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | where {$_.FolderPath -notmatch ".snapshot"} | %{$_.FolderPath + ($_.File | select Path).Path}
        write-host ("Found "+ $SearchResult.Count + " VMX files in datastore.")
 
        # Register .VMX files with vCenter, check if VM is already registered
        $VMXRegisterActions=0
        $VMXfilesSkipped=0
        foreach($VMXFile in $SearchResult) {
            if ($knownVMTable.Contains((split-path $VMXFile -leaf).split(".")[0] )) {
                $VMXfilesSkipped++
                write-host "VMXfile $vmxfile already registered. Skipping"
            } else {
                $VMXRegisterActions++
                $tasklist[(New-VM -VMFilePath $VMXFile -VMHost $ESXHost -Location $VMFolder -RunAsync).id]=(split-path $VMXFile -leaf).split(".")[0]
            }
         }
    }

    # Check running tasks
    $runningTasks=$tasklist.Count
    $VMXSuccesfullyRegistered=0
    $VMXFailed2Register=0
    while($runningTasks -gt 0) {
        get-task | %{
            if ($tasklist.ContainsKey($_.id)){
                switch ($_.state) {

                "Success" {
                    $VMXSuccesfullyRegistered++
                    $tasklist.Remove($_.id)
                    $runningTasks--
                    }

                "Error" {
                    $VMXFailed2Register++
                    $tasklist.Remove($_.id)
                    $runningTasks--
                    }
                }
            }
        }
        start-sleep -Seconds 5 # check tasks every 5 seconds
    }
    write-host "VMX files Registered: $VMXSuccesfullyRegistered, Skipped: $VMXfilesSkipped, failed: $VMXFailed2Register  "
}

End{
    #-- we made it, exit script.
    $NormalExit=$true
    exit-script
}