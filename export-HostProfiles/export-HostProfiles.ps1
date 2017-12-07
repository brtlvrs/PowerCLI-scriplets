Begin {
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

    function exit-script {
        <#
        .DESCRIPTION
            Clean up actions before we exit the script.
        #>
        [CmdletBinding()]
        Param()
        #-- disconnect vCenter connections (if there are any)
        if ((Get-Variable -Scope global -Name DefaultVIServers -ErrorAction SilentlyContinue ).value) {
            Disconnect-VIServer -server * -Confirm:$false
        }
        #-- clock time and say bye bye
        $ts_end=get-date
        write-host ("Runtime script: {0:hh}:{0:mm}:{0:ss}" -f ($ts_end- $TS_start)  )
        read-host "End script. bye bye ([Enter] to quit.)"
        exit
        }

    Function import-PowerCLI {

        #-- Load PowerCLI
        if (get-module -ListAvailable vmware*) {
        } else {
            write-host "No PowerCLi modules found."
            exit-script
        }
        #-- Load all PowerCLI modules
        while (((get-module vmware*).count -lt ((get-module -listavailable vmware*).count)) -or $err1) {
            get-module -ListAvailable vmware* | import-module -ErrorVariable Err1
        }
        #-- exit if failed
        if ($err1) {
            write-host "Failed to load PowerCLI."
            write-host $err1
            exit-script
        }
    }

}
Process {
    import-module vmware.powercli -ErrorVariable Err1
    write-host "Connecting to vCenter"
    connect-viserver -server $p.vCenter -ErrorVariable Err1
    if ($Err1) {
        write-host -ForegroundColor yellow "Failed to connect to vCenter."
        exit-script
    }
    $serial=get-date -f "yyyyMMdd-hhmmss" 
    $export=@()
    write-host "Exporting host profiles"
    foreach ($HostProfile in (Get-VMHostProfile)) {
       $export+= Export-VMHostProfile -FilePath ($p.exportfolder+"\"+$HostProfile.name+"-$serial."+$p.hostprofileextension) -profile $HostProfile -Force
    }
    $export | ft -AutoSize
}


End {
    exit-script
}