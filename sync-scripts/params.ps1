<#
Parameter file for script
#>

@{
    prefixLogMsg="[vRA sync-scripts] "
    tmpLocation="c:\temp" #-- location to store script and/or other files
    ExactCommonModule="\\nlc1vraprx01\scripts\Exact-Common\exact-common-uncPATH.psm1" #-- location for Exact common Module functions
    MSIWatchdogValue=600 #-- [s] Time before waiting on running MSI installer will fail

    #-- software installation parameters
    scripts=@(
        "install-IIS"
        ,"install-SQL2014"
        ,"install-SQL2016"
        ,"install-VCRT2008"
        ,"install-SQL2014"
        ,"install-Office2013"
        ,"install-Office2016"
        ,"exact-common"
        ,"install-DotNet35"
        ,"install-DotNet47"
    )
}
