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
			# If setmaxclock is set, try to set those puppies.
			if sys.argv[1] is "setmaxclock":
        			print("Attempting to set the max MEM and SM clocks for each interface.")
				nvmlDeviceSetApplicationsClocks(handle, nvmlDeviceSetApplicationsClocks(handle, NVML_CLOCK_MEM, NVML_CLOCK_SM)) # Set max SM
			else:
				print("Not setting the max clocks because \"setmaxclock\" wasn't sent as an argument")
		except NVMLError as error:
			print(error)
else:
	print("No devices found! Please ensure your drivers are installed properly and you've restarted.")

nvmlShutdown()
