@{
    #-- string to filter items in VMware Online Depot
   vCenter="10.30.30.31" # FQDN vCenter
   noDisconnectOnExit=$true #-- don't disconnect from the vCenter on script exit.

   #-- VM hardening parameters
   vmHardening=@{
    "isolation.tools.copy.disable"=$true
    "isolation.tools.dnd.disable"=$true
    "isolation.tools.paste.disable"=$true
    "isolation.tools.diskShrink.disable"=$true
    "isolation.tools.diskWiper.disable"=$true
    "mks.enable3d"=$false
    "tools.setinfo.sizeLimit"="1048576"
    "RemoteDisplay.vnc.enabled"=$false
    "tools.guestlib.enableHostInfo"=$false
   }
}