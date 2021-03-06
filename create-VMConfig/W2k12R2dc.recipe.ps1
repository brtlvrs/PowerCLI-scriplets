﻿@{
    Description="Recipe for Windows 2012 R2 VM with 3 disks (one for pagefile)."
    
    VM=@{
        name="templ_w2k12r2dc-test"
        floppy=$false
        GuestID="windows8Server64Guest" 
        MemoryGB=4
        NumCPU=2
        version="v13"
        DiskGB=35
        DiskStorageFormat="Thin" #-- EagerZeroedThick,Thick,Thin
        HARestartPriority="ClusterRestartPriority" #-- Disabled,Highest,High,Medium,Low,Lowest,ClusterRestartPriority
        HAIsolationResponse="AsSpecifiedByCluster" #-- DoNothing,PowerOff,Shutdown,AsSpecifiedByCluster
        DrsAutomationLevel="AsSpecifiedByCluster" #-- Manual,PartialyAutomated,FullyAutomated,AsSpecifiedByCluster,Disabled
        }
    vmdk=@{
        disk1=@{
            CapacityGB=5
            StorageFormat="thin" #-- Thin, Thick, EagerZeroedThick
            persistence ="Persistent" #-- Persistent, IndependentPersistent, IndependentNonPersistent
            }
        disk2=@{
            CapacityGB=5
            StorageFormat="thin" #-- Thin, Thick, EagerZeroedThick
            persistence ="IndependentPersistent" #-- Persistent, IndependentPersistent, IndependentNonPersistent
            }
    }
    
    network=@{
        nic1=@{
            NetworkName="vlan3030"
            StartConnected=$true
            type="vmxnet3"
        }
    }
advSetting=@{
    "vcpu.hotadd"=$true
    "mem.hotadd"=$true
    "isolation.tools.copy.disable"=$true
    "isolation.tools.dnd.disable"=$true
    "isolation.tools.paste.disable"=$true
    "isolation.tools.diskShrink.disable"=$true
    "isolation.tools.diskWiper.disable"=$true
    "mks.enable3d"=$false
    "tools.setinfo.sizeLimit"="1048576"
    "RemoteDisplay.vnc.enabled"=$false
    "tools.guestlib.enableHostInfo"=$false
    }    
}