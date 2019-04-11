#####################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
#####################################################################

#######################################################################
#
# Core_Offline_CPU_SMP.ps1
#
# Description:
#    This script will verify CPU can be offline permanently by boot 
#    with nr_cpus=xx
#
#######################################################################
<#
.Synopsis
    Verify CPU can be offline permanently by boot with nr_cpus=xx
.Description
    This script will verify CPU can be offline permanently by boot with nr_cpus=xx
.Parameter vmName
    Name of the test VM.
.Parameter hvServer
    Name of the Hyper-V server hosting the VM.
.Parameter testParams
    The amount of CPU to be set
.Example

.Link
    None.
#>

param([string] $vmName, [string] $hvServer, [string] $testParams)
$remotescript = ""

if ($vmName -eq $null){
    "Error: VM name is null"
    return $False
}

 if ($hvServer -eq $null){
    "Error: hvServer is null"
    return $False
}

 if ($testParams -eq $null){
    "Error: testParams is null"
    return $False
}

# Write out test Params
$testParams
# sshKey used to authenticate ssh connection and send commands
$sshKey = $null
 # IP Address of first VM
$ipv4 = $null
$retVal = $False

$summaryLog = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue

$params = $testParams.Split(";")
foreach ($p in $params){
    $fields = $p.Split("=")

     switch ($fields[0].Trim())
    {
        "ipv4"    { $ipv4    = $fields[1].Trim() }
        "sshKey"  { $sshKey  = $fields[1].Trim() }
        "TC_COVERED" { $TC_COVERED = $fields[1].Trim() }
        "rootDir"       { $rootDir = $fields[1].Trim() }
    }
}

# Change the working directory to where we need to be
if (-not (Test-Path $rootDir)) {
    "Error: The directory `"${rootDir}`" does not exist!"
    return $false
}
cd $rootDir

if (Test-Path ".\setupScripts\TCUtils.ps1"){
    . .\setupScripts\TCUtils.ps1
}
else{
    Write-Output "Error: Could not find setupScripts\TCUtils.ps1"
    return $False
}
if (Test-Path ".\setupScripts\NET_UTILS.ps1") {
    . .\setupScripts\NET_UTILS.ps1
}
else {
    Write-Output "ERROR: Could not find setupScripts\NET_Utils.ps1"
    return $False
}

# Execute the DisableRulesAndRegenerateInitrd
SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix Core_Parameter_maxcpus.sh && chmod u+x Core_Parameter_maxcpus.sh"
$retVal = SendCommandToVM $ipv4 $sshKey ". /root/Core_Parameter_maxcpus.sh DisableRulesAndRegenerateInitrd"
if ($retVal -eq $false){
    Write-Output "Error: Re-generate Initrd not corret."
    return $False
}

# Execute the AddKernelParameter_maxcpus
SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix Core_Parameter_maxcpus.sh && chmod u+x Core_Parameter_maxcpus.sh"
$retVal = SendCommandToVM $ipv4 $sshKey ". /root/Core_Parameter_maxcpus.sh AddKernelParameter_maxcpus"
if ($retVal -eq $false){
    Write-Output "Error: Set kernel parameter not corret."
    return $False
}

# Reboot th VM
SendCommandToVM $ipv4 $sshKey "reboot"
Write-Output "Rebooting the VM."

# Waiting the VM to start up
$sts = GetIPv4AndWaitForSSHStart $vmName $hvServer $sshKey 300
if (-not $sts){
    Throw "Error: VM not detected after restart."
}

# Excute the checkCPUNum
$retVal = SendCommandToVM $ipv4 $sshKey ". /root/Core_Parameter_maxcpus.sh OnOffCPUsTest"
if ($retVal -eq $false){
    Write-Output "Error: OnOffCPUsTest not corret."
    return $False
}

# Excute the checkCPUNum
$retVal = SendCommandToVM $ipv4 $sshKey ". /root/Core_Parameter_maxcpus.sh CheckCPUNumAndGoOffline"
if ($retVal -eq $false){
    Write-Output "Error: Checking CPU online not corret."
    return $False
}

# Excute the CheckVMBus
$retVal = SendCommandToVM $ipv4 $sshKey ". /root/Core_Parameter_maxcpus.sh CheckVMBus"
if ($retVal -eq $false){
    Write-Output "Error: Checking CPU should not attached to vmbus."
    return $False
}

return $True