#-- Load PowerCLI
if (get-module -ListAvailable vmware*) {
} else {
    write-host "Geen PowerCLI gevonden."
    Exit
}
while (((get-module vmware*).count -lt ((get-module -listavailable vmware*).count)) -or $err1) {
    get-module -ListAvailable vmware* | import-module -ErrorVariable Err1
}
if ($err1) {
    write-host "Mislukt om PowerCLI te laden."
    write-host $err1
    exit
}

#-- connect to vCenters
$oldVC=connect-viserver sjdvmvw02 -ErrorVariable Err1
$newVC=connect-viserver sjdvmvw04 -ErrorVariable Err1
if ($err1 ) {
    write-host "Mislukt om te verbinden met een vCenter."
    write-host $err1
    exit
}

#-- select root Folders
$RootFolderSrc=get-folder -type vm -server $oldVC | select name,parent | sort name | Out-GridView -PassThru -Title "Wat is de rootfolder waarvan de subfolders gekopieerd moet worden ?"
$RootFolderDst=get-folder -type vm -server $newVC | select name,parent | sort name | Out-GridView -PassThru -Title "Wat is de rootfolder waarin de folders aangemaakt moeten worden ?"
$RootFolderSrc=get-folder $RootFolderSrc.name -Server $oldVC
$RootFolderDst=get-folder $RootFolderDst.name -server $newVC

#-- copy structure and list VMs
function copy-vmFolder {
   param(
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [VMware.Vim.Folder]$OldFolder,
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   $ParentOfNewFolder,
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [string]$NewVC,
   [parameter(Mandatory = $true)]
   [ValidateNotNullOrEmpty()]
   [string]$OldVC
   )
   #-- create new folder
  $NewFolder = New-Folder -Location $ParentOfNewFolder -Name $OldFolder.Name -Server $NewVC
  #-- list VMs with their new folder ID
  Get-VM -NoRecursion -Location ($OldFolder|Get-VIObjectByVIView) -Server $OldVC|Select-Object Name, @{N='Folder';E={$NewFolder.id}}
  #-- create for each subfolder a new folder
  foreach ($childfolder in $OldFolder.ChildEntity|Where-Object {$_.type -eq 'Folder'})
    {
    copy-vmFolder -OldFolder (Get-View -Id $ChildFolder -Server $OldVC) -ParentOfNewFolder $NewFolder -NewVC $NewVC -OldVC $OldVC
    }

}

$result=@()
foreach ($oldFolder in (get-folder -type vm -server $oldVC | ?{$_.parent.name -eq $RootFolderSrc.name})) {
    $result+=copy-vmFolder -OldFolder $oldFolder.ExtensionData -ParentOfNewFolder $RootFolderDst -NewVC $NewVC.name -OldVC $OldVC.name
}
#-- display VMs location in new vCenter
$result | ft -AutoSize