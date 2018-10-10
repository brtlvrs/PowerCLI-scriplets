function get-elevatedStatus{
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

    # Check to see if we are currently running "as Administrator"
    return $myWindowsPrincipal.IsInRole($adminRole)
}
function run-elevated {
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

    # Check to see if we are currently running "as Administrator"
    if ($myWindowsPrincipal.IsInRole($adminRole))
       {

       # We are running "as Administrator" - so change the title and background color to indicate this
        Syslog-Info -message "Script already running elevated."

       }
    else
       {
        syslog-info -message "(run-elevated) restart powershell in ellevated process"
       Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction SilentlyContinue -ErrorVariable Err1
       if ($err1) {
            Syslog-Error -message "Could not run script elevated."
            exit-script
       }
       #-- process succesfully started, so exit this session
       exit
       }

}
