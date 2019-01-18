#!/usr/bin/env python3
from py3nvml.py3nvml import *
import sys

nvmlInit()
deviceCount = nvmlDeviceGetCount()
if deviceCount > 0:
    for i in range(deviceCount):
        try:
            handle = nvmlDeviceGetHandleByIndex(i)
            maxSM = int(nvmlDeviceGetMaxClockInfo(handle, NVML_CLOCK_SM))
            enSM = int(nvmlDeviceGetApplicationsClock(handle, NVML_CLOCK_SM))
            maxMem = int(nvmlDeviceGetMaxClockInfo(handle, NVML_CLOCK_MEM))
            enMem = int(nvmlDeviceGetApplicationsClock(handle, NVML_CLOCK_MEM))
            maxPw = nvmlDeviceGetPowerManagementLimitConstraints(handle)[-1] # get last value for max power
            enPw = nvmlDeviceGetEnforcedPowerLimit(handle)
            fanSpeed = nvmlDeviceGetFanSpeed(handle)

            deviceName = nvmlDeviceGetName(handle)
            print("{}:{}, Fan%:[{}], Mem:[{}], SM:[{}], Pwr:[{}]".format(i, deviceName, fanSpeed, str(enSM)+"MHz", str(enMem)+"MHz", str(enPw)[:3]+"Watts"))
            nvmlDeviceSetPersistenceMode(handle, 1) # Set persistence so it sticks until reboot
            # Don't set clock if already set
            if enSM != maxSM or enMem != maxMem: 
                print("Attempting to set the max MEM and SM clocks for each interface.")
                oc = nvmlDeviceSetApplicationsClocks(handle, maxMem, maxSM)
            else:
                print("Max clock is already set")
            # Don't set power if already set
            if enPw != maxPw:
                print("Changing power from "+str(enPw)[:3]+" to "+str(maxPw)[:3])
                mp = nvmlDeviceSetPowerManagementLimit(handle, maxPw)
            else:
                print("Max power is already set")
        except NVMLError as error:
            print(error)
else:
    print("No devices found! Please ensure your drivers are installed properly and you've restarted.")
nvmlShutdown()
