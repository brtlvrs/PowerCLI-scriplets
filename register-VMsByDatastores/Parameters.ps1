# Script Parameters for <scriptname>.ps1
<#
    Author             : Bart Lievers
    Last Edit          : <Initials> - <date>
                         BL - 27-11-2016
    Copyright 2016 - CAM IT Solutions
#>

#-- Type definitions needed for syslog function
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

@{
#-- default script parameters
 LogPath="D:\beheer\logs"
 LogDays=5 #-- Logs older dan x days will be removed

#-- Syslog
 SyslogServer="sjdvlog01.ict.lan"

#-- disconnect viServer in exit-script function
 DisconnectviServerOnExit=$true

#-- vSphere vCenter FQDN
 vCenter="srv-vmvw-03.itnet.local" #-- description of param1
}