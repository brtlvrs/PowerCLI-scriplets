**apply-AdvancedSettings**
PowerCLI script to apply list of advanced settings to VMs

### LICENSE
This script is released under the MIT license. See the License file for more details

| | |
|---|---|
| Version | 0.0.1|
| branch | master|

### CHANGE LOG

|build|branch |  Change |
|---|---|---|
|0.0| n.a.| Initial release|

### How to setup

1. download script with parameters.ps1
1. edit parameters.ps1
1. run script

### Dependencies

- PowerShell 3.0
- PowerCLI > 6.5.x

### Parameters.ps1

The parameters file contains the following parameters

|Name|Usage|
|---|---|
|vCenter| FQDN or IPv4 of Vcenter server to connect to
|noDisconnectOnExit| Don't disconnect from vCenter on exit script
|vmHardening| [hashtable] VM advanced parameters table, each parameter has its own line. [parameter name] = [value]