#
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
#

. /lib/functions.sh

board_name=""
[ -f /tmp/sysinfo/board_name ] &&
	board_name=$(cat /tmp/sysinfo/board_name)

mcc_platform=1
yocto_build=0
owrt_build=0

case "$board_name" in
	*sdxlemur-65*)
		yocto_build=1
		if [ -f /etc/initscripts/start_wsplcd-mcc ]; then
			WSPLCD_INIT="/etc/initscripts/start_wsplcd-mcc"
		else
			WSPLCD_INIT="/etc/initscripts/start_wsplcd"
		fi
		if [ -f /etc/initscripts/start_ezmesh-mcc ]; then
			EZMESH_INIT="/etc/initscripts/start_ezmesh-mcc"
		else
			EZMESH_INIT="/etc/initscripts/start_ezmesh"
		fi
		if [ -f /etc/initscripts/start_hyfi-bridging-mcc ]; then
			HYFI_BRIDGING_INIT="/etc/initscripts/start_hyfi-bridging-mcc"
		else
			HYFI_BRIDGING_INIT="/etc/initscripts/start_hyfi-bridging"
		fi
		if [ -f /usr/sbin/hyctl_mcc ]; then
			HYCTL="/usr/sbin/hyctl_mcc"
		else
			HYCTL="/usr/sbin/hyctl"
		fi
		;;
	*)
		owrt_build=1
		WSPLCD_INIT="/etc/init.d/wsplcd"
		EZMESH_INIT="/etc/init.d/ezmesh"
		HYFI_BRIDGING_INIT="/etc/init.d/hyfi-bridging"
		HYCTL="/usr/sbin/hyctl"
		;;
esac

get_wlan_module_path() {
	if [ $yocto_build -eq 1 ]; then
		wlan_module_path=/var/run
	else
		wlan_module_path=/data/vendor/wifi
	fi

	echo "$wlan_module_path"
}

get_hostapd_global_ctrl_interface() {
	if [ $yocto_build -eq 1 ]; then
		hostapd_global_ctrl_interface="hostapd/global"
	else
		hostapd_global_ctrl_interface="hostapd-global"
	fi

	echo "$hostapd_global_ctrl_interface"
}

get_ko_path() {
	release=$(uname -r | awk -F '.' '{print $1,$2}' | tr ' ' '.')
	if [ -d /lib/modules/$release-debug ]; then
		echo "/lib/modules/$release-debug/extra"
	elif [ -d /lib/modules/$release-perf ]; then
		echo "/lib/modules/$release-perf/extra"
	elif [ $(cat /firmware/verinfo/Ver_Info.txt | grep -c "PINNACLES_LE.2.0") = 1 ]; then
		echo "/lib/modules/$(uname -r)/extra"
	else
		echo ""
	fi
}

get_lwe_tool_name() {
	lwe_tool=ifconfig
	echo "$lwe_tool"
}
