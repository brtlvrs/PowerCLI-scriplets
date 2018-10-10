Function Get-RegistryValue($key, $value) {  
    (Get-ItemProperty $key $value).$value  
 } 

Function Set-RegistryValue($key, $name, $value, $type="Dword") {  
    If ((Test-Path -Path $key) -Eq $false) { New-Item -ItemType Directory -Path $key | Out-Null }  
         Set-ItemProperty -Path $key -Name $name -Value $value -Type $type  
  }  
  
Function Get-UACLevel(){ 
    $Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $ConsentPromptBehaviorAdmin_Name="ConsentPromptBehaviorAdmin"
    $PromptOnSecureDesktop_Name="PromptOnSecureDesktop"
    
    $ConsentPromptBehaviorAdmin_Value = Get-RegistryValue $Key $ConsentPromptBehaviorAdmin_Name 
    $PromptOnSecureDesktop_Value = Get-RegistryValue $Key $PromptOnSecureDesktop_Name 
    If($ConsentPromptBehaviorAdmin_Value -Eq 0 -And $PromptOnSecureDesktop_Value -Eq 0){ 
        Syslog-Info -message "UACLevel : [0] Never notIfy" 
        $UAClevel=0
    } 
    ElseIf($ConsentPromptBehaviorAdmin_Value -Eq 5 -And $PromptOnSecureDesktop_Value -Eq 0){ 
        Syslog-Info -message "UACLevel : [1] NotIfy me only when apps try to make changes to my computer(do not dim my desktop)" 
        $UAClevel=1
    } 
    ElseIf($ConsentPromptBehaviorAdmin_Value -Eq 5 -And $PromptOnSecureDesktop_Value -Eq 1){ 
        Syslog-Info -message "UACLevel : [2] NotIfy me only when apps try to make changes to my computer(default)" 
        $UAClevel=2
    } 
    ElseIf($ConsentPromptBehaviorAdmin_Value -Eq 2 -And $PromptOnSecureDesktop_Value -Eq 1){ 
        Syslog-Info -message "UACLevel : [3] Always notIfy" 
        $UAClevel=3
    } 
    Else{ 
        Syslog-Info "UACLevel : Unknown" 
        $UAClevel=99
    } 
    return $UAClevel
} 

Function Set-RegistryValue($key, $name, $value, $type="Dword") {  
    If ((Test-Path -Path $key) -Eq $false) { New-Item -ItemType Directory -Path $key | Out-Null }  
         Set-ItemProperty -Path $key -Name $name -Value $value -Type $type  
  }  

Function Set-UACLevel() { 
    Param([int]$Level= 2) 
    
    New-Variable -Name PromptOnSecureDesktop_Value 
    New-Variable -Name ConsentPromptBehaviorAdmin_Value 

    $Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" 
    $ConsentPromptBehaviorAdmin_Name = "ConsentPromptBehaviorAdmin" 
    $PromptOnSecureDesktop_Name = "PromptOnSecureDesktop"

    If($Level -In 0, 1, 2, 3) {
        $ConsentPromptBehaviorAdmin_Value = 5 
        $PromptOnSecureDesktop_Value = 1 
        Switch ($Level) {  
        0 {
            $ConsentPromptBehaviorAdmin_Value = 0
            $PromptOnSecureDesktop_Value = 0
          }  
          1 { 
              $ConsentPromptBehaviorAdmin_Value = 5
              $PromptOnSecureDesktop_Value = 0 
          }
          2 {
              $ConsentPromptBehaviorAdmin_Value = 5
              $PromptOnSecureDesktop_Value = 1
          }
          3 {
              $ConsentPromptBehaviorAdmin_Value = 2
              $PromptOnSecureDesktop_Value = 1
          }
        }
        Set-RegistryValue -Key $Key -Name $ConsentPromptBehaviorAdmin_Name -Value $ConsentPromptBehaviorAdmin_Value 
        Set-RegistryValue -Key $Key -Name $PromptOnSecureDesktop_Name -Value $PromptOnSecureDesktop_Value 
 
        Get-UACLevel 
    } 
    Else{ 
        "No supported level" 
    } 
     
} 
