write-verbose "Loading script functions."
# Gather all files
$Functions  = @(Get-ChildItem -Path ($scriptpath+"\functions") -Filter *.ps1 -ErrorAction SilentlyContinue)

# Dot source the functions
ForEach ($File in @($Functions)) {
    Try {
        . $File.FullName
    } Catch {
        Write-Error -Message "Failed to import function $($File.FullName): $_"
    }       
}

# Export the public functions for module use
Export-ModuleMember -Function $Functions.Basename
