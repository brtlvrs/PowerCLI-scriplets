function confirm-MSIrun {
    <#
    .SYNOPSIS  
        Returns $true if MSI installer is running
    .NOTES  
        Author         : Bart Lievers
    #>	
    $isRunning=$true
    try
    {
        $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
        $Mutex.Dispose();
     #   Write-Host "An installer is currently running."
    }
    catch
    {
     #   Write-Host "An installer is not currently runnning."
        $isRunning=$false
    }
    return $isRunning
}

function wait-onMSI {
    <#
    .SYNOPSIS  
        Returns $true waiting for MSI to finish timedout
    .DESCRIPTION
        Waiter function that checks every 5 seconds if MSI installer is finished.
        It will return $true if we wait too long. It returns $false when MSI installer finished before we timed out.
    .PARAMETER timeout
        [S] Period before function returns $true while waiting on finishing MSI installer.
    .NOTES  
        Author         : Bart Lievers
    #>	
    Param(
        [int]$timeout=180 #-- time to wait before failing
    )
    $timedOut=$false
    $ts_startWatchdog=get-date
    $timedOut=((get-date) - $ts_startWatchdog).TotalSeconds -gt $timeout  
    while (!$timedOut -and (confirm-MSIrun)) {
        #-- check every 5 seconds if MSI is still running
        Start-Sleep -Seconds 5
        $timedOut=((get-date) - $ts_startWatchdog).TotalSeconds -gt $timeout          
    }
    return $timedOut
}
