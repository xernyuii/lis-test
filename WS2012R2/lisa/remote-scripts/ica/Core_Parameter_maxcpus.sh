#!/bin/bash

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

#Source utils.sh
dos2unix utils.sh
. utils.sh || {
    UpdateTestState "TestAborted"
    UpdateSummary "Error: unable to source utils.sh!"
    exit 2
}

# Source constants.sh
dos2unix constants.sh
. constants.sh || {
    UpdateTestState "TestAborted"
    UpdateSummary "Error: unable to source constants.sh!"
    exit 2
}

ChangeRules(){
    #sed -i '/ SUBSYSTEM=="cpu"/s/^#//' /lib/udev/rules.d/40-redhat.rules
    sed -i 's/SUBSYSTEM=="cpu"/# &/' /lib/udev/rules.d/40-redhat.rules
    dracut -f
    if [ $? -eq 0 ]; then
        LogMsg "Passed: Comment out rules and re-generate initrd."
    else
        LogMsg "Failed: Re-generate initrd error."
        UpdateSummary "Failed: Re-generate initrd error."
        UpdateTestState "TestFailed"
        exit 2
    fi
}

# Offline and online cpu which has no vmbus channels attached
OnOffCPUs(){
    startcpu=${MAXCPUs}
    endcpu=$((${VCPU}-1))
    i=${startcpu}
    GetDistro

    while [[ $i -lt $endcpu ]];
    do
	    echo 1 > "/sys/devices/system/cpu/cpu${i}/online"
        if [ $? -ne 0 ]&&[ $DISTRO == "redhat_8" ]; then
            LogMsg "Failed: CPU ${i} cannot offline."
            UpdateSummary "Failed: CPU ${i} cannot offline."
            UpdateTestState "TestFailed"
            exit 2
        fi
	    sleep 1
	    echo 0 > "/sys/devices/system/cpu/cpu${checkcpu}/online"

	    i=$((i+1))
    done

    CheckCallTracesWithDelay 20
}

CheckCPUOffline()
{
	testcpustart=$1
	testcpuend=$2
	
	# check CPUs attached should not go offline
	for ((i=${testcpustart}; i<=${testcpuend}; i++))
	do
		echo 0 > /sys/devices/system/cpu/cpu${i}/online
		if [ $? -ne 0 ]; then
            LogMsg "Passed: CPU ${i} cannot offline."
        else
            LogMsg "Failed: CPU ${i} offline unexpectedly."
            UpdateSummary "Failed: CPU ${i} offline unexpectedly."
            UpdateTestState "TestFailed"
            exit 2
        fi
	done
}

#Check CPU numbers
checkCPUNum(){
    cpunum=`grep processor /proc/cpuinfo | wc -l`

	# Check cpu number by /proc/cpuinfo
	if [ ${cpunum} -eq $((${VCPU}-1)) ]; then
        LogMsg "Passed: CPU number is ${VCPU}"
    else
        LogMsg "Failed: CPU number is not ${VCPU}"
        UpdateSummary "Failed: CPU number is not ${VCPU} (actual ${cpunum})"
        UpdateTestState "TestFailed"
        exit 2
    fi
}

CheckVMBus(){
    yum install -y hyperv-tools
    if [[ $? -ne 0 ]]; then
        LogMsg "Unable to install hyperv-tools."
        UpdateTestState "TestFailed"
        exit 2
    fi

    startcpu=${MAXCPUs}
    endcpu=$((${VCPU}-1))
    i=${startcpu}
    while [[ $i -lt $endcpu ]];
    do
        if [ `lsvmbus -vv | grep target_cpu=${i} | wc -l` -ne 0 ]; then
            LogMsg "Failed: CPU ${i} has vmbus attached."
            UpdateSummary "Failed: CPU ${i} has vmbus attached."
            UpdateTestState "TestFailed"
            exit 2
        fi
	    i=$((i+1))
    done
}

if [ $1 = "AddKernelParameter_maxcpus" ]; then
    ChangeKernelParamter maxcpus=${MAXCPUs}
elif [ $1 = "AddKernelParameter_nr_cpus" ]; then
    ChangeKernelParamter nr_cpus=${NRCPUs}
elif [ $1 = "DisableRulesAndRegenerateInitrd" ]; then
    ChangeRules
elif [ $1 = "CheckCPUNumAndGoOffline" ]; then
    #checkCPUNum
    CheckCPUOffline 0 $((${MAXCPUs}-1))
elif [ $1 = "OnOffCPUsTest" ]; then
    OnOffCPUs
elif [ $1 = "CheckVMBus" ]; then
    CheckVMBus
fi