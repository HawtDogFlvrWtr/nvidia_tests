#/usr/bin/env python
from py3nvml.py3nvml import *
import sys

nvmlInit()
deviceCount = nvlmDeviceGetCount()
if len(deviceCount) > 0:
	for i in range(deviceCount):
		try:
			handle = nvlmDeviceGetHandleByIndex(i)
			maxSM = nvmlDeviceSetApplicationsClocks(handle, NVML_CLOCK_SM)
			maxMem = nvmlDeviceSetApplicationsClocks(handle, NVML_CLOCK_MEM)
			deviceName = nvmlDeviceGetName(handle)
			fanSpeed = nvmlDeviceGetFanSpeed(handle)
			print("ID, Name, Fan RPM, MaxSM, MaxMem")
			print("{}: {}, {}, {}, {}".format(i, deviceName, fanSpeed, maxSM, maxMem))
			# Check if we have perms to actually set the clocks correctly
			if sys.argv[1] is "setmaxclock":
        print("Attempting to set the max MEM and SM clocks for each interface.")
				nvmlDeviceSetApplicationsClocks(handle, nvmlDeviceSetApplicationsClocks(handle, NVML_CLOCK_SM)) # Set max SM
				nvmlDeviceSetApplicationsClocks(handle, nvmlDeviceSetApplicationsClocks(handle, NVML_CLOCK_MEM)) # Set max Mem
		except NVMLError as error:
			print(error)
else:
	print("No devices found! Please ensure your drivers are installed properly and you've restarted.")

nvmlShutdown()
