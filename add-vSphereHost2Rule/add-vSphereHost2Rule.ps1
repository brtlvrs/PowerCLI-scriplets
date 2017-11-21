$viCenter=read-host "Wat is het vCenter server address ? [FQDN]"



if (get-module -ListAvailable vmware*) {
} else {
    write-host "Geen PowerCLI gevonden."
    Exit
}
while (((get-module vmware*).count -lt ((get-module -listavailable vmware*).count)) -or $err1) {
    get-module -ListAvailable vmware* | import-module -ErrorVariable Err1
}
if ($err1) {
    write-host "Mislukt om PowerCLI te laden."
    write-host $err1
    exit
}
while (($global:DefaultVIServer.IsConnected -eq $null) -or $err1) {
    connect-viserver $viCenter -ErrorVariable Err1
}
if ($err1) {
    write-host "Mislukt om te verbinden met $viCenter"
    write-host $err1
    exit
}

#-- deployrule to modify
$DR_update=get-deployrule -ErrorVariable Err1 -name  (get-deployruleset | select -ExpandProperty rulelist | Out-GridView -PassThru -Title "Selecteer de rule waar de host aan toegevoegd moet worden.").name
if ($err1) {
    write-host " Cannot find deploy rule"
    exit
}

#-- select vSphere host to add to deployrule
$vmhost2Add=get-vmhost | sort name | Out-GridView -PassThru -Title 'Welke vSphere host wordt toegevoegd ?'
#-- check if host is in maintenance mode
while ($vmhost2Add.ConnectionState -ne 'Maintenance') {
    Do {
        $answer=read-host ($vmHost2Add.name + " staat niet in maintenance mode (heb je wel de goede host geselecteerd ?) ? [yN]")
        Switch -Regex ($answer) {
            "\A(Y|y)\Z" {
                $loopDone=$true
                set-vmhost -VMHost $vmhost2Add -State Maintenance -Evacuate -Confirm:$false
                break
            }
            "\A(n|N|)\Z" {
                $answer="N"
                exit
                $loopdone=$true
                break
            }
            default { 
                $loopdone=$false
                write-host "Onbekend antwoord."
                break
            }
       }
    } until ($loopDone)    
}
$HostConnection=Test-Connection $vmhost2add.name -Count 1

#-- add IPv4 addres of vSphere host to patternlist
$patternlist=$DR_update.patternlist
$patternlist+="ipv4="+$HostConnection.IPV4Address.IPAddressToString
#-- modify deployrule
copy-deployrule -DeployRule $DR_update -ReplacePattern $patternlist
#-- Update DeployrulesetCompliance
Test-DeployRuleSetCompliance -VMHost $vmhost2ADD | FT -AutoSize
Test-DeployRuleSetCompliance -VMHost $vmhost2ADD | Repair-DeployRuleSetCompliance
get-deployruleset |ft -AutoSize
$DR_update=get-deployrule -Name $DR_update.Name
$DR_update.PatternList

Do {
    $answer=read-host ("Reboot " + $vmHost2Add.name + " ? [yN]")
    Switch -Regex ($answer) {
        "\A(Y|y)\Z" {
            $loopDone=$true
            restart-vmhost -VMHost $vmhost2Add -Confirm:$false -Evacuate:$true
            write-host "Host is restarting"
        }
        "\A(n|N|)\Z" {
            write-host "vsphere moet nog herstart worden." -ForegroundColor Yellow
            $loopdone=$true
        }
        default { 
            $loopdone=$false
            write-host "Onbekend antwoord."
        }
    }
   } until ($loopDone)

