function New-TimeStamp {
	<#
			.SYNOPSIS  
			    Returns a timestamp based on the current date and time     
			.DESCRIPTION 
			    Returns a timestamp based on the current date and time 
			.NOTES  
			    Author         : Bart Lievers
			    Copyright 2013 - Bart Lievers    

	#>	
	[cmdletbinding()]
	param()
 	return (get-date -uformat "%Y-%m-%d-%H:%M:%S")
}

function New-Watchdog {
	<#
			.SYNOPSIS  
			    Create a watchdog object     
			.DESCRIPTION  
				Retuns a watchdog timer object. 
			.PARAMETER Days
				Amount of days before watchdog will timeout
			.PARAMETER Hours
				Amount of hours before watchdog will timeout
			.PARAMETER Minutes
				Amount of minutes before watchdog will timeout
			.PARAMETER Seconds
				Amount of minutes before watchdog will timeout
			.NOTES  
			    Author         : Bart Lievers
			    Copyright 2013 - Bart Lievers    

	#>	
	[cmdletbinding()]
	param (
		[parameter(helpmessage="Amount of days for watchdog period.")][int]$Days=0,
		[parameter(helpmessage="Amount of hours for watchdog period.")][int]$Hours=0,
		[parameter(helpmessage="Amount of Minutes for watchdog period.")][int]$Minutes=0,
		[parameter(helpmessage="Amount of seconds for watchdog period.")][int]$Seconds=0
	)
	$userclass={
		[cmdletbinding()]
		param (
			[parameter(helpmessage="Amount of days for watchdog period.")][int]$Days=0,
			[parameter(helpmessage="Amount of hours for watchdog period.")][int]$Hours=0,
			[parameter(helpmessage="Amount of Minutes for watchdog period.")][int]$Minutes=0,
			[parameter(helpmessage="Amount of seconds for watchdog period.")][int]$Seconds=0
		)
		Export-ModuleMember
		#add static properties
		Set-Variable -Name StartTime -Option ReadOnly -Value (Get-Date)
		Set-Variable -Name Span -Option ReadOnly -Value (New-Timespan -Days $Days -Hours $Hours -Minutes $minutes -Seconds $Seconds)
		Export-ModuleMember -Variable StartTime,Span,Done
		
		#add dynamic property done
		function get-Done {
			[cmdletbinding()]
			#Private function to decide if watchdog is done
			param()
			(((Get-Date) - $StartTime) -ge $Span)
		}	
		Set-Variable -Name Done -Option ReadOnly -Value (get-Done)
		Export-ModuleMember -Variable Done
		
		#add dynamic property TimeElapsed
		function get-Elapsed {
			[cmdletbinding()]
			# Private function to calculate elapsed time
			param()
			((Get-Date)-$StartTime)
		}
		Set-Variable  -Name TimeElapsed -option ReadOnly -Value (get-elapsed)
		Export-ModuleMember -Variable TimeElapsed
		
		#add public function
		function isDone {
			[cmdletbinding()]
			#public function to check if watchdog is done and updates the watchdog properties
			Param()
			Set-Variable -Scope script -Name Done -Value (get-Done) -Force
			Set-Variable -Scope script -Name TimeElapsed -Value (get-Elapsed) -Force
			return ($Done)
		}
		Export-ModuleMember -Function isDone		
	}
	#return customobject
	return (New-Module -ScriptBlock $userclass -AsCustomObject -ArgumentList $days,$hours,$minutes,$seconds  )
}

function New-ProgressBar {	
		<#
			.SYNOPSIS  
			    Automation of Progressbar.       
			.DESCRIPTION  
				The function creates a custom object, designed to automate the write-progress cmdlet.
				The object contains all the mandatory parameters used for write-progress.
				It has 4 scriptsmethods to work with the write-progress cmdlet. 
				.update() Update the progressbar object  with the object parameters
				.up() Increase the step counter and update the progressbar
				.hide() hide the progress bar.
			.NOTES  
			    Author         : Bart Lievers
			    Copyright 2013 - Bart Lievers    
			.EXAMPLE  
				$P =@{
					ID=0
					Activity="Searching something"
					Status="initialize"
					CurrentOperation="Done"
					TotalSteps=15
				}
			    $a=InitProgressBar @(P)
				$a.update()	
				$a.up() # increade the step value and update the progress bar
				$a.down() # decrease the step value and update the progress bar
				$a.hide() # the progressbar is hidden
		#>
	[cmdletbinding()]
	#Define the Object properties
	Param (
		[Parameter(Mandatory=$true,
			HelpMessage="Specifies an ID that distinguishes each progress bar from the others."
			)][int]$ID=0,
		[Parameter(
			Mandatory=$false,
			HelpMessage="Identifies the parent activity of the current activity. Use the value -1 if the current activity has no parent activity."
			)][int]$ParentID=-1,
		[Parameter(Mandatory=$true,
			HelpMessage="Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported."
			)][string]$Activity,
		[Parameter(Mandatory=$true,
			HelpMessage="Specifies the second line of text in the heading above the status bar. This text describes current state of the activity."
			)][string]$Status,
		[Parameter(Mandatory=$false,
			HelpMessage="Specifies the line of text below the progress bar. This text describes the operation that is currently taking place."
			)][string]$CurrentOperation="",
		[Parameter(Mandatory=$false,
			HelpMessage="Specifies the progress counter. This will be used to calculate the percentage of completion."
			)][int]$Step=0, #Progress step counter
		[Parameter(Mandatory=$true,
			HelpMessage="Specifies the maximum value for the progress counter. This will be used to calculate the percentage of completion."
			)][int]$TotalSteps #Maximum amount of steps
		)
	
	$objBar = New-Object PSObject
	#add object properties, these are the same as the function parameters
	$objBar |
		Add-Member -MemberType NoteProperty -Name id -Value $id -PassThru |
	 	Add-Member -MemberType NoteProperty -Name Parentid -Value $ParentID -PassThru |
	 	Add-Member -MemberType NoteProperty -Name Activity -Value $Activity -PassThru |
	 	Add-Member -MemberType NoteProperty -Name Status -Value $Status -PassThru |
	 	Add-Member -MemberType NoteProperty -Name CurrentOperation -Value $CurrentOperation  -PassThru |
	 	Add-Member -MemberType NoteProperty -Name Step -Value $Step -PassThru |
	 	Add-Member -MemberType NoteProperty -Name TotalSteps -Value $TotalSteps -PassThru |
	 	#add method scripting to the object
	 	Add-Member -MemberType ScriptMethod -Name Update -Value {
		<#
			.SYNOPSIS  
			    Update the progressbar. The stepcounter isn't incremented        
			.DESCRIPTION  
			    Update the progressbar with its properties.
				When a step index property will be updated when a new one is given.
			.NOTES  
			    Author         : Bart Lievers
			    Prerequisite   : PowerShell V2 over Vista and upper.
			    Copyright 2013 - Bart Lievers    
			.EXAMPLE  
			    $a.status="New state"
				$a.update()	
			.EXAMPLE
				$a.status="another state with custom step"
				$a.update(3)
		#>
        param([int]$Step=-1)
		#Parameter validatie
		If ($Step -ge 0) {$this.step=$step}
		if ($this.status.length -eq 0) {
			$This.status = " "
			$this.CurrentOperation = ""} # When there is no status, there is no currentoperation
		if ($this.CurrentOperation.length -eq 0) {
			$this.CurrentOperation = ""}
		if ($this.totalsteps -gt 0) {
			#Parameters verzamelen om in 1x door te geven
			$WP_param=@{
				currentoperation =$this.currentoperation
				id = $this.id
				parentid = $this.parentid
				activity = $this.activity
				status = $this.status
				percentcomplete = ($this.step/$this.totalsteps)*100
				}
			#Update de Progressbar
	    	Write-Progress @WP_Param
			}
	
		} -PassThru | #Einde scriptmethod update
	 Add-Member -MemberType ScriptMethod -Name Up -Value {
	 	#Methode om de progressbar incrementeel te laten groeien
	 	if ($this.step -ge $this.totalsteps) {
			# we zitten aan het maximum van de stappen
			$this.step= $this.totalsteps
		}
	 	if ($this.step -lt $this.totalsteps) {
			$this.step  += 1
		}
		#parameter validatie
		if ($this.status.length -eq 0) {
			$This.status = " "
			$this.CurrentOperation = ""}
		if ($this.CurrentOperation.length -eq 0) {
			$this.CurrentOperation = ""}
		$WP_param=@{
			currentoperation =$this.currentoperation
			id = $this.id
			parentid = $this.parentid
			activity = $this.activity
			status = $this.status
			percentcomplete = ($this.step/$this.totalsteps)*100
			}
	    Write-Progress @WP_Param	
		} -PassThru | # einde scriptmethod Up
	 Add-Member -MemberType ScriptMethod -Name Down -Value {
	 	#Methode om de progressbar incrementeel te laten groeien
	 	if ($this.step -le 0) {
			# We cannot go below the 0 value
			$this.step= 0
		}
	 	if ($this.step -gt 0) {
			$this.step  += -1
		}
		#parameter validation
		if ($this.status.length -eq 0) {
			$This.status = " "
			$this.CurrentOperation = ""}
		if ($this.CurrentOperation.length -eq 0) {
			$this.CurrentOperation = ""}
		$WP_param=@{
			currentoperation =$this.currentoperation
			id = $this.id
			parentid = $this.parentid
			activity = $this.activity
			status = $this.status
			percentcomplete = ($this.step/$this.totalsteps)*100
			}
	    Write-Progress @WP_Param	
		} -PassThru | # einde scriptmethod Down
	 Add-Member -MemberType ScriptMethod -Name hide -Value {
	 	#verberg de progressbar
		$WP_param=@{
			currentoperation =$this.currentoperation
			id = $this.id
			parentid = $this.parentid
			activity = $this.activity
			status = $this.status
			percentcomplete = 100
			}
	    Write-Progress @WP_Param -completed	
		} #einde scriptmethod hide
	
	#Return the created Progressbar object
	Return $objBar
} #Einde Create-ProgressBar functie

function Select-FileDialog {
	<#
	.SYNOPSIS  
	    Select file(s) through windows .net file dialog.   
	.DESCRIPTION  
		Let the user select files with the windows file dialog.
		It returns the openfiledialog object
		The -MultipleFiles switch decides if one or more files will be selected.
	.PARAMETER Title
		The File dialog title
	.PARAMETER Directory
		The Directory where to start. [optional]
	.PARAMETER Filter
		The filter to be used. [optional]
		Default  All Files (*.*)|*.*
	.PARAMETER MultipleFiles
		Switch parameter, when present multiple files can be selected
	.EXAMPLE
		$c = select-filedialog -Title "Select files" -Filter "NetApp Messages(Messages*)|messages*" -MultipleFiles
	.NOTES  
	    Author         	: Bart Lievers
		Created on		: 6-5-2013
	    Copyright 2013 - Bart Lievers   	
	#>
	[cmdletbinding()]
	param(
		[string]$Title,
		[string]$Directory,
		[string]$Filter="All Files (*.*)|*.*",
		[switch]$MultipleFiles)
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	$objForm = New-Object System.Windows.Forms.OpenFileDialog
	if (($directory.length -eq 0) -or !(Test-Path -IsValid $Directory -ErrorAction SilentlyContinue) ) {$Directory=$env:homedrive}
	$objForm.InitialDirectory = $Directory
	$objForm.Filter = $Filter
	$objForm.Title = $Title
	$objForm.MultiSelect = $MultipleFiles
	$Show = $objForm.ShowDialog()
	If ($Show -eq "OK")
	{
		$objForm.filenames
		Return 
	}
	Else
	{
		Write-Error "Er zijn geen bestanden geselecteerd."
	}
} #Select-FileDialog

Function New-TextLog {
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
		helpmessage="Location of log file. Default the %temp% folder.")]
		$location=$env:temp,	
	[Parameter(Mandatory=$false,
		helpmessage="File extension to be used. Default is .log")]
		$extension=".log"
	)
	Write-Verbose "Input parameters"
	Write-Verbose "`$name:$name"
	Write-Verbose "`$location:$location"
	Write-Verbose "`$extension:$extension"
	if (!(Test-Path -IsValid $path\$name$extension)) {Write-Warning "Opgegeven naam en/of location zijn niet correct. $location\$name.$extenstion"; exit}
	$obj = New-Object psobject
	$obj | Add-Member -MemberType NoteProperty -Name file -Value $location\$name$extension -PassThru |
	Add-Member -MemberType NoteProperty -Name Location -Value $location -PassThru |
	Add-Member -MemberType ScriptMethod -Name log -Value {
		param(
			[string]$message
		)
		if (!(Test-Path $this.file)) {$this.create()}
		$message = "{0:dd-MMM-yy hh:mm:ss}" -f (Get-Date) + " $message"
		Out-File -FilePath $this.file -Append -Width $message.length -InputObject $message
	} -PassThru |
	Add-Member -MemberType ScriptMethod -Name write -Value {
		param(
			[string]$message
		)
		if (!($message)) {Out-File -FilePath $this.file -Append -InputObject ""} Else {
		Out-File -FilePath $this.file -Append -Width $message.length -InputObject $message}
	} -PassThru |
	Add-Member -MemberType ScriptMethod -Name create -value {
		Out-File -FilePath $this.file -InputObject "======================================================================"
		$this.write("")
		$this.write("	log file:" + $this.file)
		$this.write("	created on: {0:dd-MMM-yyy hh:mm:ss}" -f (Get-Date))
		$this.write("======================================================================")
	} -PassThru |
	Add-Member -MemberType ScriptMethod -Name remove -value {
		if (Test-Path $this.file) {Remove-Item $this.file}
	} -PassThru | Out-Null 	
	$obj.create() |out-null
	Return $obj
}

function Connect-Filer {
	<#
			.SYNOPSIS  
			    Connect to Cam NetApp Filer.    
			.DESCRIPTION 
			    Connect to Cam NetApp Filer.  
			.NOTES  
			    Author         : Bart Lievers
			    Copyright 2013 - Bart Lievers    

	#>	
	[cmdletbinding()]
	param(
		[parameter(helpmessage="FQDN, IP or resolvable host name of NetApp Filer",
			ValueFromPipeline=$true)]
		[string]$Filer,
		[parameter(helpmessage="Credentials for connection to Filer.")]
		$Creds
		
	)
	#Check if credentials are given, else warn
	if (!($Creds)) {Write-Log "Geen credentials opgegeven voor Filer $filer." -isError}
	#Connect to NetApp Filer and capture result in array
	if (!(Test-Connection -ComputerName $Filer -Quiet )) {
		write-log "$Filer is niet gevonden op het netwerk, er kan geen verbinding worden opgebouwd." -iserror 
		exit}
	[array]$result=Connect-NaController -Credential $creds -Name $Filer -HTTP -erroraction SilentlyContinue -errorvariable ConErr
	#Output the result
	if ($result) {
		# We are connected, so get some more info and parse the connection result to the log
		$SystemInfo = Get-NaSysteminfo 
		write-log ("Ingelogd op NetApp filer "+$SystemInfo.Systemname+" ($Filer)")
		$result[0] | fl | out-string -Width 80 | write-log
	} else {
		#Bummer, something went wrong. Let's log it
		write-log  ("Geen verbinding kunnen maken met NetApp Filer: "+ $filer +"`n"+ $ConErr) -iserror
		exit}
	return ($SystemInfo)
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
		[Parameter(helpmessage="Messagelevel is [warning.]",
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
		else { Write-Warning "Geen geldig log bestand opgegeven (`$LogFilePath). Er wordt niet gelogd."}
	} 
	else {
		Write-Warning "Geen geldig log bestand opgegeven (`$LogFilePath). Er wordt niet gelogd."
	} 
	#-- write message also to designated stream
	if ($isError) {Write-Error $message}
	elseif ($iswarning) {Write-Warning $message}
	elseif ($isDebug) {Write-Debug $message}
	else {Write-Verbose $message}
} #-- end of Write-Log function

Function New-Log {
	<#
	.SYNOPSIS  
	    Create a new log file, or append a header to an existing one.   
	.DESCRIPTION 
	    Create a new log file, or append a header to an existing one.
	.NOTES  
	    Author         : Bart Lievers
	    Copyright 2013 - Bart Lievers
	.PARAMETER LogFile
		The Logfile to create or use.
	.PARAMETER Scriptname
		The name of the script we are processing
	.PARAMETER Add
		Don't start a new logfile, append to an existing one.
	#>	
	[cmdletbinding()]
	Param(
		[Parameter(helpmessage="Location of logfile.",Mandatory=$false)][string]$LogFile,
		[Parameter(helpmessage="Name of Script to display.",Mandatory=$false)][string]$ScriptName,
		[Parameter(helpmessage="Add to existing log, if exists.",Mandatory=$false)][switch]$Add
	)
	if ($ScriptName.length -eq 0) {
		$ScriptName = $MyInvocation.scriptname
	}
	if ($LogFile.length -eq 0) {
		$LogPath = split-path -parent $ScriptName
		$LogPath=$LogPath +"\log"
		if (!(Test-Path $LogPath)) {
			Write-Warning ($LogPath + " bestaat niet. Er wordt een poging gedaan om deze aan te maken.")
			if (Test-Path $LogPath -IsValid ) {	New-Item $LogPath -type Directory}
			if (!(Test-Path $LogPath)) {
			Write-Warning Geen log directory kunnen aanmaken.
			break}
		}
		$global:LogFilePath = $LogPath+ "\"+ (split-path -leaf $ScriptName)+".log"
		$LogFile = $LogFilePath
	}
	if ($LogFile.length -gt 0) {
		if (!(Test-Path $LogFile)) {	
			Out-File -FilePath $LogFile
			Write-Host ("Log file "+ $LogFile + " is aangemaakt.")
		}
		if (Test-Path $LogFile) {
				#-- write header to log file
			if (!($add)) {
				Out-File -FilePath $LogFile
				}
			("----------- "+ (new-timestamp) + " -----------------------------------") | Out-File -FilePath $LogFile -Append
			("--")  | Out-File -FilePath $LogFile -Append
			("--    Logfile: $LogFilePath") | Out-File -FilePath $LogFile -Append
			("--    Script: "+ $ScriptName)  | Out-File -FilePath $LogFile -Append
			("--")  | Out-File -FilePath $LogFile -Append
			("-------------------------------------------------------------------")  | Out-File -FilePath $LogFile -Append
			} 
		else { Write-Warning "Geen geldige logfile opgegeven. Er wordt niet gelogd."}
		} 
	else {
			Write-Warning "Geen geldige logfile opgegeven (`$LogFilePath). Er wordt niet gelogd."} 	
	
}

New-Alias New-txtLog New-TextLog
Export-ModuleMember -Function * -Alias *