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

Function new-ID {
    <#
    .SYNOPSIS
    Generate a unique ID
    .DESCRIPTION
    Generating a unique ID based on the current date and time. Creating a SHA1 hash as result
    #>
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

    #-- log wrappers
Function Syslog-Info {
    Param (
        [string]$message,
        [string]$SyslogServer=$global:SyslogServer,
        $log=$global:log
    )
    $msg= ($prefixLogMsg + " " + $message)
    $log.verbose($msg)
    $msg = "[INFO] " + $msg
    Send-SyslogMessage -Server $SyslogServer -Facility local0 -Severity Informational -Message $msg
}

Function Syslog-Debug {
    Param (
        [string]$message,
        [string]$SyslogServer=$global:SyslogServer,
        $log=$global:log
    )
    $msg= ($prefixLogMsg + " " + $message)
    $log.debug($msg)
    $msg = "[Debug] " + $msg
    Send-SyslogMessage -Server $SyslogServer -Facility local0 -Severity Informational -Message $msg
}

Function Syslog-Warning {
    Param (
        [string]$message,
        [string]$SyslogServer=$global:SyslogServer,
        $log=$global:log
    )
    $msg= ($prefixLogMsg + " " + $message)
    $log.warning($msg)
    $msg = "[WARNING] " + $msg
    Send-SyslogMessage -Server $SyslogServer -Facility local0 -Severity Warning -Message $msg
}

Function Syslog-Error {
    Param (
        [string]$message,
        [string]$SyslogServer=$global:SyslogServer,
        $log=$global:log
    )
    $msg= ($prefixLogMsg + " " + $message)
    $log.error($msg)
    $msg = "[WARNING] " + $msg
    Send-SyslogMessage -Server $SyslogServer -Facility local0 -Severity Error -Message $msg
}

Function Write-Log {
    <#
    .SYNOPSIS  
        Write message to logfile   
    .DESCRIPTION 
        Write message to logfile and associated output stream (error, warning, verbose etc...)
        Each line in the logfile starts with a timestamp and loglevel indication.
        The output to the different streams don't contain these prefixes.
        The message is always sent to the verbose stream.
    .NOTES  
        Author         : Bart Lievers
        Copyright 2013 - Bart Lievers 
    .PARAMETER LogFilePath
        The fullpath to the log file
    .PARAMETER message
        The message to log. It can be a multiline message
    .Parameter NoTimeStamp
        don't add a timestamp to the message
    .PARAMETER isWarning
        The message is a warning, it will be send to the warning stream
    .PARAMETER isError
        The message is an error message, it will be send to the error stream
    .PARAMETER isDebug
        The message is a debug message, it will be send to the debug stream.
    .PARAMETER Emptyline
        write an empty line to the logfile.
    .PARAMETER toHost
        write output also to host, when it has no level indication
    #>	
    [cmdletbinding()]
    Param(
        [Parameter(helpmessage="Location of logfile.",
                    Mandatory=$false,
                    position=1)]
        [string]$LogFile=$LogFilePath,
        [Parameter(helpmessage="Message to log.",
                    Mandatory=$false,
                    ValueFromPipeline = $true,
                    position=0)]
        $message,
        [Parameter(helpmessage="Log without timestamp.",
                    Mandatory=$false,
                    position=2)]
        [switch]$NoTimeStamp,
        [Parameter(helpmessage="Messagelevel is [warning]",
                    Mandatory=$false,
                    position=3)]
        [switch]$isWarning,
        [Parameter(helpmessage="Messagelevel is [error]",
                    Mandatory=$false,
                    position=4)]
        [switch]$isError,
        [Parameter(helpmessage="Messagelevel is [Debug]",
                    Mandatory=$false,
                    position=5)]
        [switch]$isDebug,
        [Parameter(helpmessage="Messagelevel is [Verbose]",
                    Mandatory=$false,
                    position=5)]
        [switch]$isVerbose,
        [Parameter(helpmessage="Write an empty line",
                    Mandatory=$false,
                    position=6)]
        [switch]$EmptyLine
    )
    # Prepare the prefix
    [string]$prefix=""
    if ($isError) {$prefix ="[Error]       "}
    elseif ($iswarning) {$prefix ="[Warning]     "}
    elseif ($isDebug) {$prefix="[Debug]       "}
    elseif ($isVerbose) {$prefix="[Verbose]     "}
    else {$prefix ="[Information] "}
    if (!($NoTimeStamp)) {
            $prefix = ((new-TimeStamp) + " $prefix")}
    if($EmptyLine) {
        $msg =$prefix
    } else {
        $msg=$prefix+$message}
    #-- handle multiple lines
    $msg=[regex]::replace($msg, "`n`r","", "Singleline") #-- remove multiple blank lines
    $msg=[regex]::Replace($msg, "`n", "`n"+$Prefix, "Singleline") #-- insert prefix in each line
    #-- write message to logfile, if possible
    if ($LogFile.length -gt 0) {
        if (Test-Path $LogFile) {
            $msg | Out-File -FilePath $LogFile -Append -Width $msg.length } 
        else { Write-Warning "No valid log file (`$LogFilePath). Cannot write to log file."}
    } 
    else {
        Write-Warning "No valid log file (`$LogFilePath). Cannot write to log file."
    } 
    #-- write message also to designated stream
    if ($isError) {
            Write-Error $message
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Alert}
            }
    elseif ($iswarning) {
            Write-Warning $message
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Warning}
            }
    elseif ($isDebug) {
            Write-Debug $message
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Debug}
            }
    elseif ($isVerbose) {
            Write-Verbose $message           
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Debug}
            }
    else {Write-host $message                
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Informational}
            }
} 


function New-TimeStamp {
    <#
        .SYNOPSIS  
            Returns a timestamp based on the current date and time     
        .DESCRIPTION 
            Returns a timestamp based on the current date and time 
        .NOTES
            Author         : Bart Lievers
            Copyright 2013 - Bart Lievers
        .PARAMETER Sortable
            [switch] Make the timestamp sortable. like YYYYMMDD instead of DDMMYYYY
        .PARAMETER Serial
            [switch]  Remove seperation characters. Fur usage in filenames
        .PARAMETER noSeconds
            [switch] don't return the seconds in the timestamp
    #>	
    [cmdletbinding()]
    param(
        [switch]$Sortable,
        [switch]$serial,
        [switch]$noSeconds
        )
        $TimeFormat="%H:%M:%S"
        if ($Sortable) {
            $TimeFormat="%Y-%m-%d-%H:%M:%S"
        } else {
            $TimeFormat="%d-%m-%Y-%H:%M:%S"	
        }
        if($serial){
            $TimeFormat=$TimeFormat.replace(":","").replace("-","")
        }
        if ($noSeconds) {
            $TimeFormat=$TimeFormat.replace(":%S","").replace("%S","")
        
        }
        return (Get-Date -UFormat $TimeFormat)
    
}
    
Function New-LogObject {
    <#
    .SYNOPSIS  
        Creating a text log file. Returning an object with methods to ad to the log     
    .DESCRIPTION  
        The function creates a new text file for logging. It returns an object with properties about the log file.	
        and methods of adding logs entry
    .NOTES  
        Author         : Bart Lievers
        Copyright 2013 - Bart Lievers   	
    #>
    [cmdletbinding()]
    param(
    [Parameter(Mandatory=$true,
        helpmessage="The name of the eventlog to grab or create.")][string]$name,
    [Parameter(Mandatory=$false,
        helpmessage="Add a timestamp to the name of the logfile")][switch]$TimeStampLog,		
    [Parameter(Mandatory=$false,
        helpmessage="Location of log file. Default the %temp% folder.")]
        [string]$location=$env:temp,	
    [Parameter(Mandatory=$false,
        helpmessage="File extension to be used. Default is .log")]
        $extension=".log",
    [Parameter(Mandatory=$false)]
        [int]$keepNdays=14
    )

    #-- verbose parameters
    Write-Verbose "Input parameters"
    Write-Verbose "`$name:$name"
    Write-Verbose "`$location:$location"
    Write-Verbose "`$extension:$extension"
    Write-Verbose "`$keepNdays:$keepNdays"
    Write-Verbose "`$TimeStampLog:$TimeStampLog"

    #-- determine log filename
    if ($TimeStampLog) {
        $Filename=((new-timestamp -serial -sortable -noSeconds )+"_"+$name+$extension)
    } else {		
        $Filename=$name+$extension
    }
    $FullFilename=$location + "\" +  $filename

    write-host ("Log file : "+$fullfilename)
    if (Test-Path -IsValid $FullFilename) {
        #-- filepath is valid
        $path=Split-Path -Path $FullFilename -Parent
        $ParentPath=Split-Path $FullFilename -Parent
        $folder=Split-Path -Path $ParentPath -Leaf
        if (! (Test-Path $path)) {
            #file path doesn't exist
            if ($ParentPath.length -gt 3) {
                New-Item -Path $path -ItemType directory -Value $folder
            }
        }
    }
    else{
        Write-Warning "Invalid path for logfile location. $FullFilename"
        exit}
            
    #-- create PS object
    $obj = New-Object psobject
    #-- add properties to the object
    Add-Member -InputObject $obj -MemberType NoteProperty -Name file -Value $FullFilename
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Name -Value $name
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Location -Value $location
    Add-Member -InputObject $obj -MemberType ScriptMethod -Name write -Value {
        param(
            [string]$message
        )
        if (!($message)) {Out-File -FilePath $this.file -Append -InputObject ""} Else {
        Out-File -FilePath $this.file -Append -Width $message.length -InputObject $message}}
    Add-Member -InputObject $obj -MemberType ScriptMethod -Name create -value {
        Out-File -FilePath $this.file -InputObject "======================================================================"
        $this.write("")
        $this.write("         name : "+ $this.name)		
        $this.write("	  log file : " + $this.file)
        $this.write("	created on : {0:dd-MMM-yyy hh:mm:ss}" -f (Get-Date))
        $this.write("======================================================================")
    }
    Add-Member -InputObject $obj -MemberType ScriptMethod -Name remove -value {
        if (Test-Path $this.file) {Remove-Item $this.file}
    }
    add-member -InputObject $obj -MemberType ScriptMethod -Name msg -Value {
        param(
            [string]$message
        )	
        if ((Test-Path $this.file) -eq $false) { $this.create()}
        Write-Log -LogFile $this.file -message $message
    }
    add-member -InputObject $obj -MemberType ScriptMethod -Name warning -Value {
        param(
            [string]$message
        )	
        if ((Test-Path $this.file) -eq $false) { $this.create()}	
        Write-Log -LogFile $this.file -message $message -isWarning
    }
    add-member -InputObject $obj -MemberType ScriptMethod -Name debug -Value {
        param(
            [string]$message
        )	
        if ((Test-Path $this.file) -eq $false) { $this.create()}	
        Write-Log -LogFile $this.file -message $message -isDebug
    }
    add-member -InputObject $obj -MemberType ScriptMethod -Name error -Value {
        param(
            [string]$message
        )		
        if ((Test-Path $this.file) -eq $false) { $this.create()}
        Write-Log -LogFile $this.file -message $message -isError
    }
    add-member -InputObject $obj -MemberType ScriptMethod -Name verbose -Value {
        param(
            [string]$message
        )	
        if ((Test-Path $this.file) -eq $false) { $this.create()}	
        Write-Log -LogFile $this.file -message $message -isVerbose
    }
    add-member -InputObject $obj -MemberType ScriptMethod -Name emptyline -Value {
        param(
            [string]$message
        )	
        if ((Test-Path $this.file) -eq $false) { $this.create()}	
        Write-Log -LogFile $this.file  -EmptyLine
    }

    #-- logfile cleanup maintenance
    clear-LogFiles -keepNdays $keepNdays -logObj $obj | Out-Null

    #-- create logfile
    $obj.create() |out-null

    #-- return log object
    $obj
    Return 
}

Function clear-LogFiles {
    <#
        .SYNOPSIS
            purge logfiles older then  specified days
        .DESCRIPTION
            purge logfiles older then  specified days.
            It expects a global variable called log. That variable should be created by the new-logobject function
        .PARAMETER keepNdays
            Keep the last N days of logfiles    
    #>
    param(
        [int]$keepNdays,
        [object]$logObj
    )

    if ($logObj) {
        
    } else {
        #-- check if global log variable exists
        if ((Test-Path variable:global:log) -eq $false) {
            Write-Error "Unable to purge old logfiles, cannot find global log variable."
            exit
        } else {
            $logobj=$log
        }
    }
    #-- check if log variable contains the location property
    if ((test-path $logobj.Location) -eq $false) {
        Write-Error "Log variable doesn't contain location property, cannot purge old logfiles."
        exit	
    }

    Write-Verbose ("Cleaning up old log files for "+$logobj.file)
    #-- determine date	
    $limit = (Get-Date).AddDays(-$keepNdays)
    $logobj.msg("Log files older then "+ $limit+ " will be removed.")
    #-- purge older logfiles
    gci $logobj.Location | ? {	-not $_.PSIsContainer -and $_.CreationTime -lt $limit -and ($_.name -ilike ("*"+$logobj.name+".log")) } | Remove-Item
}

Function Write-Log {
    <#
    .SYNOPSIS  
        Write message to logfile   
    .DESCRIPTION 
        Write message to logfile and associated output stream (error, warning, verbose etc...)
        Each line in the logfile starts with a timestamp and loglevel indication.
        The output to the different streams don't contain these prefixes.
        The message is always sent to the verbose stream.
    .NOTES  
        Author         : Bart Lievers
        Copyright 2013 - Bart Lievers 
    .PARAMETER LogFilePath
        The fullpath to the log file
    .PARAMETER message
        The message to log. It can be a multiline message
    .Parameter NoTimeStamp
        don't add a timestamp to the message
    .PARAMETER isWarning
        The message is a warning, it will be send to the warning stream
    .PARAMETER isError
        The message is an error message, it will be send to the error stream
    .PARAMETER isDebug
        The message is a debug message, it will be send to the debug stream.
    .PARAMETER Emptyline
        write an empty line to the logfile.
    .PARAMETER toHost
        write output also to host, when it has no level indication
    #>	
    [cmdletbinding()]
    Param(
        [Parameter(helpmessage="Location of logfile.",
                    Mandatory=$false,
                    position=1)]
        [string]$LogFile=$LogFilePath,
        [Parameter(helpmessage="Message to log.",
                    Mandatory=$false,
                    ValueFromPipeline = $true,
                    position=0)]
        $message,
        [Parameter(helpmessage="Log without timestamp.",
                    Mandatory=$false,
                    position=2)]
        [switch]$NoTimeStamp,
        [Parameter(helpmessage="Messagelevel is [warning]",
                    Mandatory=$false,
                    position=3)]
        [switch]$isWarning,
        [Parameter(helpmessage="Messagelevel is [error]",
                    Mandatory=$false,
                    position=4)]
        [switch]$isError,
        [Parameter(helpmessage="Messagelevel is [Debug]",
                    Mandatory=$false,
                    position=5)]
        [switch]$isDebug,
        [Parameter(helpmessage="Messagelevel is [Verbose]",
                    Mandatory=$false,
                    position=5)]
        [switch]$isVerbose,
        [Parameter(helpmessage="Write an empty line",
                    Mandatory=$false,
                    position=6)]
        [switch]$EmptyLine,
        [Parameter(helpmessage="Also send message to syslog",
                    Mandatory=$false,
                    position=7)]
        [switch]$Log2SysLog
    )
    # Prepare the prefix
    [string]$prefix=""
    if ($isError) {$prefix ="[Error]       "}
    elseif ($iswarning) {$prefix ="[Warning]     "}
    elseif ($isDebug) {$prefix="[Debug]       "}
    elseif ($isVerbose) {$prefix="[Verbose]     "}
    else {$prefix ="[Information] "}
    if (!($NoTimeStamp)) {
            $prefix = ((new-TimeStamp) + " $prefix")}
    if($EmptyLine) {
        $msg =$prefix
    } else {
        $msg=$prefix+$message}
    #-- handle multiple lines
    $msg=[regex]::replace($msg, "`n`r","", "Singleline") #-- remove multiple blank lines
    $msg=[regex]::Replace($msg, "`n", "`n"+$Prefix, "Singleline") #-- insert prefix in each line
    #-- write message to logfile, if possible
    if ($LogFile.length -gt 0) {
        if (Test-Path $LogFile) {
            $msg | Out-File -FilePath $LogFile -Append -Width $msg.length } 
        else { Write-Warning "No valid log file (`$LogFilePath). Cannot write to log file."}
    } 
    else {
        Write-Warning "No valid log file (`$LogFilePath). Cannot write to log file."
    } 
    #-- write message also to designated stream
    if ($isError) {
            Write-Error $message
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Alert}
            }
    elseif ($iswarning) {
            Write-Warning $message
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Warning}
            }
    elseif ($isDebug) {
            Write-Debug $message
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Debug}
            }
    elseif ($isVerbose) {
            Write-Verbose $message           
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Debug}
            }
    else {Write-host $message                
            if ($Log2SysLog) {Send-syslog -Message $message -Severity Informational}
            }
} 
