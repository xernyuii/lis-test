########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0  
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################



<#
.Synopsis
    Import a VM into HyperV if the VM does not exist.

.Description
    Import a VM into localhost HyperV if the VM does not exist.
    If the VM exists, the script will return with no action taken. 
    
.Parameter VMDir
    The folder which contains the VM. 

.Parameter VMName
    Name of the VM. In general it is the VM folder name.

.Parameter LogFolder
    A folder to save the script running logs.

.Exmple
    Import-LisaVM.ps1 D:\VmRepository Windows-X86-01 D:\Logs

#>

param( [string]$VMDir, [string]$VMName, [string]$LogFolder )

#----------------------------------------------------------------------------
# Start a new PowerShell log.
#----------------------------------------------------------------------------
Start-Transcript "$LogFolder\Import-LisaVM.ps1.log" -force

#----------------------------------------------------------------------------
# Print running information
#----------------------------------------------------------------------------
Write-Host "Running [Import-LisaVM.ps1]..." -foregroundcolor cyan
Write-Host "`$VMDir        = $VMDir" 
Write-Host "`$VMName       = $VMName" 
Write-Host "`$LogFolder    = $LogFolder" 

#----------------------------------------------------------------------------
# Verify required parameters
#----------------------------------------------------------------------------
if ($VMDir -eq $null -or $VMDir -eq "")
{
    Throw "Parameter VMDir is required."
}
if ($VMName -eq $null -or $VMName -eq "")
{
    Throw "Parameter VMName is required."
}
if ($LogFolder -eq $null -or $LogFolder -eq "")
{
    Throw "Parameter LogFolder is required."
}

$vmNumber = 0
If ($VMName.Contains(":"))
{
    $VmList = $VMName.Split(":")
    $vmNumber = $VmList.Count
    Write-Host "There are $vmNumber VMs defined in the LISA XML (separator char ':'): $VMName"
}
else
{
    $VmList = $VMName
    $vmNumber = 1
    Write-Host "There is one VM defined in the LISA XML: $VMName"
}

for ($i=0; $i -lt $vmNumber; $i++)
{
    if ($vmNumber -eq 1)
    {
        $theVMName = $VmList
    }
    else
    {
        $theVMName = $VmList[$i]
    }

    #----------------------------------------------------------------------------
    # Remove a VM if its name already exists in HyperV manager (if not, the start vm will fail because the VM files are being used by HyperV)
    #----------------------------------------------------------------------------
    $VMSvr = Get-WmiObject -namespace "Root\Virtualization\V2" "Msvm_VirtualSystemManagementService"
    $VM = Get-WmiObject -namespace "Root\Virtualization\V2" -query "SELECT * FROM Msvm_ComputerSystem WHERE Caption='Virtual Machine' and elementName= '$theVMName'"

    if($VM -ne $null)
    {
	    Write-Host "The VM $theVMName was found already exist in the HyperV manager. Exiting..."
    }
    else
    {
        $VMFullName = "$VMDir\$theVMName"
        Write-Host "Importing $VMFullName into Hyper-V ..." 

        $vmConfig = Get-Item "$VMDir\$theVMName\Virtual Machines\*.xml"
        Compare-VM -path $vmconfig
        Import-VM �CPath $vmconfig
    }
}
Write-Host "Running [Import-LisaVM.ps1] FINISHED (NOT VERIFIED)."

Stop-Transcript
exit