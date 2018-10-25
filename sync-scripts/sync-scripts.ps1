<#
.SYNOPSIS
    Script for synchronising scripts between MYC1VRAPRX01 and NLC1VRAPRX01
.DESCRIPTION
    Script for synchronising scripts between MYC1VRAPRX01 and NLC1VRAPRX01
#>
[CmdletBinding()]
Param()

Begin {
    #-- determine script location and name

    $global:SyslogServer="nlc1vrlog01.exactsoftware.com" #-- FQDN or IP of syslog server    
    $scriptpath=get-item (Split-Path -parent $MyInvocation.MyCommand.Definition)
    $scriptNameFull=Split-Path -Leaf $MyInvocation.mycommand.path
    $scriptname=$scriptNameFull.Split(".")[0]
    $P=& $scriptpath\params.ps1

    #-- script static parameters
    $Files2CleanUp=@() #-- array to register file names which needs to be cleaned up when script is finished.
    $syslogReachable=(Test-netconnection -ComputerName $global:syslogserver).pingsucceeded | out-null

    #-- sanity check on tmpLocation
    if ($P.tmpLocation -inotmatch ".*\/^") { $P.tmpLocation=$P.tmpLocation+"\"}

    function exit-script 
    {
        <#
        .DESCRIPTION
            Standard code to run on exit.
            Basicly the last code that will be run before script is exited.
            Removing files that are mentioned in the $Files2Cleanup array
        #>
        [CmdletBinding()]
        param()
    
        #-- check why script is called and react apropiatly
        if ($finished_normal) {
            $msg = "Script executed normaly."
        } else {
            $msg = "Script executed with warnings."
        }
    
        #-- General cleanup actions
        if ($Files2CleanUp.count -gt 0) {
            syslog-info "Temporary files registered to cleanup"
            foreach ($file in $Files2CleanUp) {
                if (test-path $file) {
                    get-item $file | remove-item -Confirm:$false -ErrorVariable Err1 -Force
                    if ($err1) {
                        syslog-warning "Cleanup of file $file failed with error $err1"
                    }
                } else {
                    Syslog-Info "File $file not found to cleanup."
                }
            }
        }
    
        #-- Output runtime and say greetings
        $ts_end=get-date
        $msg=$msg + " Script execution time: {0:hh}:{0:mm}:{0:ss}" -f ($ts_end- $ts_start)  
        Syslog-Info -message $msg
        exit
    }

    #-- script initialization
    try {
        import-module $P.ExactCommonModule | out-null
    }
    catch {
        throw {write-host "Failed to load exact-common module."}
        exit
    }

    $ts_start=get-date #-- note start time of script
    if (test-path variable:global:finished_normal) {Remove-Variable -Name finished_normal -Confirm:$false }
   
    #-- Start of script initialization 

   #--seting up logging, variables need to be global so log functions can pick them up
   $global:log=New-LogObject -TimeStampLog -name $scriptname -location $scriptpath
   #-- rewrite prefix for log Message
   $global:prefixLogMsg =$P.prefixLogMsg + ", RunID = " + (new-id) + ", scriptname = "  + $scriptnamefull  + ", scriptpath = "  + $scriptpath  + ", msg ="
     
   Syslog-Info -message "Start script."
    #-- log parameters
    syslog-info ("localUserAccount: " + $env:USERNAME)
    syslog-info ("Userdomain: " + $env:USERDOMAIN)
    syslog-info ("tmpLocation: " + $P.tmpLocation)
    syslog-info ("syslogReachable: " + $syslogReachable)
    syslog-info ("SyslogServer: " + $SyslogServer)
    syslog-info ("scriptNameFull: " + $scriptNameFull)
}

End {
    #-- script finished normaly.
    $finished_normal=$true
    exit-script
}

Process{
    #-- set parent folder
    $parrentFolder=Split-Path $scriptpath -Parent
    $i=0
    #-- loop through script folders
    foreach ($scriptfolder in $P.scripts) {
        #-- build log prefix
        $i++
        $logpreffix=" $i/"+ $P.scripts.count + " : "
        syslog-info "$logpreffix script folder $scriptfolder"
        #-- determine src path
        $scriptFolderFull=$parrentFolder + "\" +$scriptfolder
        #-- check if path exists
        if (test-path $scriptFolderFull) {
            #-- get content of folder, excluding files in the .git subfolder structure
            $foldercontent = gci -Path $scriptFolderFull -Recurse -file | ?{$_.fullname -inotlike "*.git*"}
            if ($foldercontent.count -eq 0) {
                syslog-warning ("$logpreffix No files found to sync.")
                return
            }
            #-- loop through each file
            foreach ($item in $foldercontent) {
                Syslog-Info "$logpreffix checking file hash of $item"
                #-- build path for destination
                $subLoc=$item.FullName.Replace($parrentFolder,"")
                $dstLoc="\\myc1vraprx01\scripts" + $subLoc
                #-- build hashes
                if (test-path $dstLoc) {
                    #--destination file exists, so build hashes to compare
                    $srcHash = Get-FileHash -Path $item.FullName -Algorithm "SHA1"
                    $dstHash=  Get-FileHash -Path $dstLoc -Algorithm $srcHash.Algorithm   
                    Syslog-Debug ("$logpreffix srchash| " + $srchash.Hash)
                    Syslog-Debug ("$logpreffix dsthash| " + $dstHash.Hash)

                    $syncFile=$srchash.Hash -ne $dstHash.Hash
                } else {
                    #-- destination file doesn't exist
                    $syncfile=$true
                    #--check if destination folder exists
                    if (!(test-path (split-path $dstloc -Parent))) {
                        #-- create destination folder , it didn't exist
                        New-Item -Path (split-path $dstloc -Parent ) -ItemType Directory 
                        }
                }
                #-- syncfile
                if ($syncFile) {
                    #-- copy file
                    $dstpath = (split-path -Path $dstLoc -Parent) + "\"
                    syslog-info "$logpreffix Copying $item to $dstpath"
                    copy-item -Path $item.FullName -Destination $dstPath -Confirm:$false -ErrorVariable Err1
                    if ($err1) {
                        syslog-warning ("$logpreffix Syncing of file $item failed with " + $err1)
                    } else {
                        syslog-info ("$logpreffix File "+$item.fullname + " synced.")
                    }
                } else {
                    Syslog-Info "$logpreffix File is already synced."
                }

            }

        } else {
            syslog-warning ($scriptFolderFull + " folder not found. Unable to sync " + $scriptfolder + " with MYC1VRAPRX01")
            return
        }

    }
}
