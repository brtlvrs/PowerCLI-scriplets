[CmdletBinding()]
<#
.SYNOPSIS
    Script to install <feature or program name> in Windows OS.
.DESCRIPTION
    Script to install <feature or program name> in Windows OS.
    Script is to be executed via VM options on deployment of a VM.
    Script locations to be edited are tagged with  === TO BE EDITED ===
.PARAMETER SyslogServer
    The FQDN, hostname or IPv4 of the syslogserver to send log messages to
.Parameter vraTaskID
    The Unique vRA ID of the task which triggers this script
#>

Param(
    [string]$SyslogServer="nlc1vrlog01.exactsoftware.com",
    [string]$vraTaskID="none"
)

Begin {
    $task="Install IIS"  # === TO BE EDITED ===
    $prefixLogMsg="[vRA post-deploy] "

Add-Type -TypeDefinition @"
       public enum Syslog_Facility
       {
               kern,
               user,
               mail,
               system,
               security,
               syslog,
               lpr,
               news,
               uucp,
               clock,
               authpriv,
               ftp,
               ntp,
               logaudit,
               logalert,
               cron,
               local0,
               local1,
               local2,
               local3,
               local4,
               local5,
               local6,
               local7,
       }
"@
 
Add-Type -TypeDefinition @"
       public enum Syslog_Severity
       {
               Emergency,
               Alert,
               Critical,
               Error,
               Warning,
               Notice,
               Informational,
               Debug
          }
"@

    #-- script initialization

    $ts_start=get-date #-- note start time of script
    if (test-path variable:global:finished_normal) {Remove-Variable -Name finished_normal -Confirm:$false }

	
    function exit-script 
    {
        <#
        .DESCRIPTION
            Clean up actions before we exit the script.
        .PARAMETER unloadCcModule
            [switch] Unload the CC-function module
        .PARAMETER defaultcleanupcode
            [scriptblock] Unique code to invoke when exiting script.
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


        #-- Output runtime and say greetings
        $ts_end=get-date
        $msg=$msg + " Script execution time: {0:hh}:{0:mm}:{0:ss}" -f ($ts_end- $ts_start)  
        Syslog-Info -message $msg
        exit
    }

    Function new-ID {
        #-- generate a unqiue ID by hashing a string based on current date and time qith sha1
        $enc= [system.text.Encoding]::UTF8
        $string = get-date -f yyyyMMddhhmmss
        $sha1 = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider
        $result = foreach ($byte in $sha1.ComputeHash($enc.GetBytes($string) )) {
            "{0:X2}"-f $byte
            }
        $result = $result -join ""
        $result
    }

    function Send-SyslogMessage
        {
        <#
        .SYNOPSIS
        Sends a SYSLOG message to a server running the SYSLOG daemon
 
        .DESCRIPTION
        Sends a message to a SYSLOG server as defined in RFC 5424. A SYSLOG message contains not only raw message text,
        but also a severity level and application/system within the host that has generated the message.
 
        .PARAMETER Server
        Destination SYSLOG server that message is to be sent to
 
        .PARAMETER Message
        Our message
 
        .PARAMETER Severity
        Severity level as defined in SYSLOG specification, must be of ENUM type Syslog_Severity
 
        .PARAMETER Facility
        Facility of message as defined in SYSLOG specification, must be of ENUM type Syslog_Facility
 
        .PARAMETER Hostname
        Hostname of machine the mssage is about, if not specified, local hostname will be used
 
        .PARAMETER Timestamp
        Timestamp, myst be of format, "yyyy:MM:dd:-HH:mm:ss zzz", if not specified, current date & time will be used
 
        .PARAMETER UDPPort
        SYSLOG UDP port to send message to
 
        .INPUTS
        Nothing can be piped directly into this function
 
        .OUTPUTS
        Nothing is output
 
        .EXAMPLE
        Send-SyslogMessage mySyslogserver "The server is down!" Emergency Mail
        Sends a syslog message to mysyslogserver, saying "server is down", severity emergency and facility is mail
 
        .NOTES
        NAME: Send-SyslogMessage
        AUTHOR: Kieran Jacobsen
        LASTEDIT: 2014 07 01
        KEYWORDS: syslog, messaging, notifications
 
        .LINK
        https://github.com/kjacobsen/PowershellSyslog
 
        .LINK
        http://aperturescience.su
 
        #>
        [CMDLetBinding()]
        Param
        (
                [Parameter(mandatory=$true)] [String] $Server,
                [Parameter(mandatory=$true)] [String] $Message,
                [Parameter(mandatory=$true)] [Syslog_Severity] $Severity,
                [Parameter(mandatory=$true)] [Syslog_Facility] $Facility,
                [String] $Hostname,
                [String] $Timestamp,
                [int] $UDPPort = 514
        )

        # Create a UDP Client Object
        $UDPCLient = New-Object System.Net.Sockets.UdpClient
        try {$UDPCLient.Connect($Server, $UDPPort)}

        catch {
            write-host "No connection to syslog server"
            return
        }
 
        # Evaluate the facility and severity based on the enum types
        $Facility_Number = $Facility.value__
        $Severity_Number = $Severity.value__
        Write-Verbose "Syslog Facility, $Facility_Number, Severity is $Severity_Number"
 
        # Calculate the priority
        $Priority = ($Facility_Number * 8) + $Severity_Number
        Write-Verbose "Priority is $Priority"
 
        # If no hostname parameter specified, then set it
        if (($Hostname -eq "") -or ($Hostname -eq $null))
        {
                $Hostname = Hostname
        }
 
        # I the hostname hasn't been specified, then we will use the current date and time
        if (($Timestamp -eq "") -or ($Timestamp -eq $null))
        {
                $Timestamp = Get-Date -Format "yyyy:MM:dd:-HH:mm:ss zzz"
        }
 
        # Assemble the full syslog formatted message
        $FullSyslogMessage = "<{0}>{1} {2} {3}" -f $Priority, $Timestamp, $Hostname, $Message
 
        # create an ASCII Encoding object
        $Encoding = [System.Text.Encoding]::ASCII
 
        # Convert into byte array representation
        $ByteSyslogMessage = $Encoding.GetBytes($FullSyslogMessage)
 
        # If the message is too long, shorten it
        if ($ByteSyslogMessage.Length -gt 1024)
        {
            $ByteSyslogMessage = $ByteSyslogMessage.SubString(0, 1024)
        }
 
        # Send the Message
        $UDPCLient.Send($ByteSyslogMessage, $ByteSyslogMessage.Length) | Out-Null
 
        }

    Function Syslog-Info {
        Param (
            [string]$message
        )
        $msg= ($prefixLogMsg + " " + $message)
        Send-SyslogMessage -Server $SyslogServer -Facility local0 -Severity Informational -Message $msg
    }


    Function Syslog-Warning {
        Param (
            [string]$message
        )
        $msg= ($prefixLogMsg + " " + $message)
        Send-SyslogMessage -Server $SyslogServer -Facility local0 -Severity Warning -Message $msg
    }

    Function Syslog-Error {
        Param (
            [string]$message
        )
        $msg= ($prefixLogMsg + " " + $message)
        Send-SyslogMessage -Server $SyslogServer -Facility local0 -Severity Error -Message $msg
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
           Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction SilentlyContinue -ErrorVariable Err1 | Out-Null
           if ($err1) {
                Syslog-Error -message "Could not run script elevated."
                exit-script
           }
           #-- process succesfully started, so exit this session
           exit
           }
    }

    #-- Start of script initialization 

    #-- determine script location and name
    $scriptpath=get-item (Split-Path -parent $MyInvocation.MyCommand.Definition)
    $scriptNameFull=Split-Path -Leaf $MyInvocation.mycommand.path
    $scriptname=$scriptNameFull.Split(".")[0]

    #-- rewrite prefix for log Message
    $prefixLogMsg = $prefixLogMsg + "vraTaskId = " + $vraTaskID + ", RunID = " + (new-id) + ", scriptname = "  + $scriptnamefull  + ", scriptpath = "  + $scriptpath  + ", task = "+$task+ ", msg ="

}

End {
    #-- script finished normaly.
    $finished_normal=$true
    exit-script
}

Process{
    Syslog-Info -message "Start script."
    run-elevated #-- only if needed  === TO BE EDITED ===

    #-- run commands depending on OS version
    $guestOS=gcim Win32_OperatingSystem | select -ExpandProperty caption
    Switch -regex ($guestOS) {

        #-- Windows 2012 or 2016
        "2016|2012" {
            #-- as an example the code to install IIS === TO BE EDITED ===
            Import-Module ServerManager
            Install-WindowsFeature -Name Web-Server,Web-Mgmt-Tools -ErrorVariable Err1 -WhatIf
            if ($err1) {
                Syslog-Error ("Installation of IIS failed with error "+ $err1)
                exit-script
            }
            if ((Get-WindowsFeature -Name web-server,web-mgmt-tools).installed) {
                Syslog-Info "IIS succesfully installed."
            } else {
                Syslog-Warning "IIS installation failed, not all required features installed."
            }
        }

        #-- OS not expected
        default {
            Syslog-Warning -message ("OS not found. System reports OS as : " + $guestOS)        
        }
    }
}
