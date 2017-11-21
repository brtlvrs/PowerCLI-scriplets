#-- Load PowerCLI
if (get-module -ListAvailable vmware*) {
} else {
    write-host "No PowerCLi modules found."
    Exit
}
#-- Load all PowerCLI modules
while (((get-module vmware*).count -lt ((get-module -listavailable vmware*).count)) -or $err1) {
    get-module -ListAvailable vmware* | import-module -ErrorVariable Err1
}
#-- exit if failed
if ($err1) {
    write-host "Failed to load PowerCLI."
    write-host $err1
    exit
}