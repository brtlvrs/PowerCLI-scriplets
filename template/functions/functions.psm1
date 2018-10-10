<#
Code to add to the begin{} block of a script

    #-- load functions
    import-module $scriptpath\functions\functions.psm1 #-- the module scans the functions subfolder and loads them as functions
    #-- add code to execute during exit script. Removing functions module
    $p.Add("cleanUpCodeOnExit",{remove-module -Name functions -Force -Confirm:$false})

#>

write-verbose "Loading script functions."
# Gather all files
if (!(Test-Path -Path ($scriptpath+"\functions"))) {
    write-Error "Couldn't reach functions folder during loading of module."
    exit
}
$FunctionFiles  = @(Get-ChildItem -Path ($scriptpath+"\functions") -Filter *.ps1 -ErrorAction SilentlyContinue)

#-- list current functions
$currentFunctions = Get-ChildItem function:
# Dot source the functions
ForEach ($File in @($FunctionFiles)) {
    Try {
        . $File.FullName
    } Catch {
        Write-Error -Message "Failed to import function $($File.FullName): $_"
    }       
}

# Export the public functions for module use
$scriptFunctions = Get-ChildItem function: | Where-Object { $currentFunctions -notcontains $_ }
foreach ($ScriptFunction in $scriptFunctions) {
    # Export the public functions for module use
    Export-ModuleMember -Function $ScriptFunction.name
}
