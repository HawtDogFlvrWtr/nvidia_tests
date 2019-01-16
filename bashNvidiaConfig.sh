#!/bin/bash
# NVIDIA CONFIG AND INSTALL FOR FEDORA(27/28/28),CENTOS,RHEL (6/7)
# By Phipps (hawtdogflvrwtr@gmail.com)

# Check if root and dump if not
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root\n" 
   exit 1
fi

# Check if we're running Optimus and dump if we suspect we are. 
lspciOut=$(lspci | grep -E "VGA|3D" | wc -l)
if [[ $lspciOut -gt 1 && $1 != "opt-bypass" ]]; then
	echo "This system contains a NVIDIA Optimus setup, and should be disabled in the bios if possible\n"
	exit 1
fi

if [[ ! -f  /tmp/cudaDriver ]]; then
	# Determine OS type for updates
	if [[ -f /etc/yum.conf ]]; then
		echo "Found yum release\n"
		configPath="/etc/yum.conf"
		updateCommand="yum"
	elif [[ -f /etc/dnf/dnf.conf ]]; then
		echo "Found dnf release\n"
		configPath="/etc/dnf/dnf.conf"
		updateCommand="dnf"
	fi

	if [[ ! -z $configPath ]]; then
		# Checking if we're excluding X11 updates with dnf, so we get the latest binaries
		xorgConfig=$(cat $configPath | grep "exclude=xorg-x11" | wc -l)

		if [[ $xorgConfig -gt 0 ]]; then
			echo "Changing $configPath to include x11 for upgrades\n"
			sed -e '/exclude=xorg-x11/ s/^#*/#/' -i $configPath
		fi
	fi

	# Update the system if we're told to
	echo "Should we automatically update the os (Y/N)?\n"
	read input
	lowerInput=${input,,} # Lower that sucker
	if [[ "$lowerInput" == *"y"* ]]; then
		eval "$updateCommand -y update"
	else
		echo "Skipping update of this sytem.\n"
	fi

	# Install depdencies
	depList = "gcc-c++ mesa-libGLU-devel libX11-devel libXi-devel libXmu-devel kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig"
	eval "$updateCommand -y install $depList"

	# Nvidia/cuda driver check for known good versions for fedora 29
	cudaDriver="./cuda_10.0.130_410.48_linux.run"
	nvidiaDriver="./NVIDIA-Linux-x86_64-415.27.run"

	if [[ ! -f $cudaDriver ]]; then
		echo "You appear to be missing the Cuda driver in this folder. Please download it from\nhttps://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux\n"
	else 
		chmod +x $cudaDriver
		echo "Kicking off cuda driver install. Please follow the steps\n"
		eval "$cudaDriver --override"
	fi

	# Add cuda configs to all user profiles on login
	cat << EOF > /etc/profile.d/cuda.sh
	pathmunge /usr/local/cuda-10.0/bin before

	if [ -z "${LD_LIBRARY_PATH}" ]; then
	    LD_LIBRARY_PATH=/usr/local/cuda-10.0/lib64
	else
	    LD_LIBRARY_PATH=/usr/local/cuda-10.0/lib64:$LD_LIBRARY_PATH
	fi

	export PATH LD_LIBRARY_PATH
EOF

	# test, compile and run
	cd /root/NVIDIA_CUDA-10.0_Samples/1_Utilities/deviceQuery/

	make
	"/usr/local/cuda-10.0"/bin/nvcc -ccbin g++ -I../../common/inc  -m64    -gencode arch=compute_30,code=sm_30 -gencode arch=compute_35,code=sm_35 -gencode arch=compute_37,code=sm_37 -gencode arch=compute_50,code=sm_50 -gencode arch=compute_52,code=sm_52 -gencode arch=compute_60,code=sm_60 -gencode arch=compute_61,code=sm_61 -gencode arch=compute_70,code=sm_70 -gencode arch=compute_70,code=compute_70 -o deviceQuery.o -c deviceQuery.cpp
	"/usr/local/cuda-10.0"/bin/nvcc -ccbin g++   -m64      -gencode arch=compute_30,code=sm_30 -gencode arch=compute_35,code=sm_35 -gencode arch=compute_37,code=sm_37 -gencode arch=compute_50,code=sm_50 -gencode arch=compute_52,code=sm_52 -gencode arch=compute_60,code=sm_60 -gencode arch=compute_61,code=sm_61 -gencode arch=compute_70,code=sm_70 -gencode arch=compute_70,code=compute_70 -o deviceQuery deviceQuery.o 
	mkdir -p ../../bin/x86_64/linux/release
	cp deviceQuery ../../bin/x86_64/linux/release
	echo "Checking to see if devices appear by running ./deviceQuery\n"
	captureDevices=$(./deviceQuery | grep 'Device 0' | wc -l)
	if [[ $captureDevices -gt 0 ]]; then
		echo "We found at least one device!\n"
	else
		echo "We didn't appear to find any devices. We're going to continue anyway...Please manually run ./deviceQuery\n"
	fi
	touch /tmp/cudaDriver
fi

if [[ ! -f /tmp/initramfsDone && -f /tmp/cudaDriver && ! -f /tmp/nvidiaDriver ]]; then
	if [[ ! -f $nvidiaDriver ]]; then
		echo "You appear to be missing the Nvidia driver in this folder. Please download it from\nhttps://www.nvidia.com/download/driverResults.aspx/141847/en-us\n"
	else
		checkBlacklist=$(grep 'blacklist=nouveau' /etc/sysconfig/grub | wc -l)
		if [[ $checkBlacklist -gt 0 ]]; then
			echo "Please manually edit the /etc/sysconfig/grub file, to ensure that the nouveau driver is disabled\nTo do so, append rd.driver.blacklist=nouveau to the end of the GRUB_CMDLINE_LINUX line, then restart this script.\nIt should look something like this: GRUB_CMDLINE_LINUX=\"rd.lvm.lv=fedora/swap rd.lvm.lv=fedora/root rhgb quiet rd.driver.blacklist=nouveau\"\n"
			exit 1
		fi
		# Remove the other OOB crap 
		checkNBL=$(grep "blacklist nouveau" /etc/modprobe.d/blacklist.conf)
		if [[ $checkNBL -eq 0 ]]; then
			echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
			# BIOS ##
			grub2-mkconfig -o /boot/grub2/grub.cfg
			## UEFI ##
			grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
		fi
		eval "$updateCommand -y remove xorg-x11-drv-nouveau"
		# Backup the old initramfs 
		mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r)-nouveau.img
		if 	dracut /boot/initramfs-$(uname -r).img $(uname -r); then
			echo "Setting system to boot to console instead of x\n"
			systemctl set-default multi-user.target
			touch /tmp/initramfsDone
			echo "Please reboot the system then run this script again as root.\n"
			exit 1
		else
			cp /boot/initramfs-$(uname -r)-nouveau.img /boot/initramfs-$(uname -r).img
			echo "Rebuilding the initramfs appeared to fail. We've restored the backup. Please run it line-by-line, yourself (commands below) and resolve any errors. Once done, reboot the server and rerun this script.\n"
			echo "mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r)-nouveau.img"
			echo "dracut /boot/initramfs-$(uname -r).img $(uname -r)\n"
			echo "If these /\/\/\/\ commands run successfully, then run the following, reboot and then rerun this script:\n"
			echo "touch /tmp/initramfsDone\n"
			echo "systemctl set-default multi-user.target\n"
		fi		

	fi
elif [[ -f /tmp/initramfsDone && -f /tmp/cudaDriver && ! -f /tmp/nvidiaDriver ]]; then
	chmod +x $nvidiaDriver
	echo "Running the nvidia driver installer. Please follow the prompts, selecting Yes for all the answers.\n"
	if [[ $nvidiaDriver ]]; then
		echo "The install appears to have finished successfully. We've set the system back to boot into X. Please restart.\n"
		systemctl set-default graphical.target
		touch /tmp/nvidiaDriver
		exit 1
	else
		echo "The install seemed to fail. Please troubleshoot the issue manully by running the install ($nvidiaDriver).\n"
	fi

elif [[ -f /tmp/nvidiaDriver ]]; then
	echo "You appear to have already successfully installed the nvidia drivers and no longer need to run this script.\n"
fi
