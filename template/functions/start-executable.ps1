function Start-Executable {
  <#
.SYNOPSIS
    Run a executable file and catch return codes to $lastexitcode
.DESCRIPTION
    Run a executable file with arguments and collect the return codes
.PARAMETER FilePath
    [string] Full path to executable to run
.Parameter Argumentlist
    [string] Array of arguments to pass to executable
#>
    param(
      [String] $FilePath,
      [String[]] $ArgumentList
    )
    $OFS = " "
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = $FilePath
    $process.StartInfo.Arguments = $ArgumentList
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    if ( $process.Start() ) {
      $output = $process.StandardOutput.ReadToEnd() `
        -replace "\r\n$",""
      if ( $output ) {
        if ( $output.Contains("`r`n") ) {
          $output -split "`r`n"
        }
        elseif ( $output.Contains("`n") ) {
          $output -split "`n"
        }
        else {
          $output
        }
      }
      $process.WaitForExit()
      & "$Env:SystemRoot\system32\cmd.exe" `
        /c exit $process.ExitCode
    }
  }
