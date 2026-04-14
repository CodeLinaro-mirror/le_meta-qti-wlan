#
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
#
#!/bin/sh

if [ -d /lib/wifi_mcc ]; then
	lib_wifi_path="/lib/wifi_mcc"
else
	lib_wifi_path="/lib/wifi"
fi

[ -f ${lib_wifi_path}/qcacld32-utils.sh ] &&
	. ${lib_wifi_path}/qcacld32-utils.sh

append DRIVERS "qcacld32"
log_file="/data/vendor/wifi/qcacld32_commands.txt"
wlandev_prefix="wifi"
wlanif_prefix="wlan"
mld_prefix="mld"
wlan_ini_name="WCNSS_qcom_cfg.ini"
wlan_ini_path="/etc/misc/wifi/"
wlan_ini_backup_path="/data/vendor/wifi"
wlan_module_path="$(get_wlan_module_path)"
hostapd_global_ctrl_interface="$(get_hostapd_global_ctrl_interface)"
gplus_str="+"
bridge_mode_enable="disable"
ipa_dynamic_ini_enable="disable"
ipa_dynamic_ini_tx_ring_enable="disable"

qlog_cmd() {
	local logText="$(date "+%Y-%m-%d %H:%M:%S") [qcacld32.sh] $@"

	[ "${ENABLE_WLAN_SCRIPT_LOG}" = "1" ] && logger -t "wlan-uci" "$logText"
	[ "${ENABLE_WLAN_SCRIPT_LOG}" = "2" ] && echo "$logText" >> $log_file

	return 0
}

sysctl_cmd() {
	qlog_cmd "sysctl -w $1=$2"

	sysctl -w $1=$2 >/dev/null 2>/dev/null
}

echo_cmd() {
	if [[ $# == 3 ]] ; then
		qlog_cmd "echo $1 $2 > $3"
		echo $1 $2 > $3
	else
		qlog_cmd "echo $1 > $2"
		echo $1 > $2
	fi
}

insmod_cmd() {
	local module_name="${1}"

	local device="$2"

	config_get country $device country

	local country_code="$country"
	if [ $country_code ];then
		country_code="country_code=$country_code"
	fi

	# WLAN modules is expected in /lib/modules/<any>/extra/
	for dirlist in $(ls "/lib/modules/"); do {
		module_name="/lib/modules/${dirlist}/extra/${1}.ko"
		if [ -f $module_name ]; then
			if [ ${1} = "wlan" ] || [ ${1} = "wlan_rome" ];then
				update_wlan_config
				qlog_cmd "*** enter insmod wlan.ko ***"
				if [ "${FORCE_USE_WLAN_CONFIG_TEMPLATE}" = "1" ];then
					qlog_cmd "skip add country code in legacy test"
					insmod ${module_name}
				else
					insmod ${module_name} $country_code
				fi
				qlog_cmd "insmod ${module_name} done"
			else
				insmod ${module_name}
				qlog_cmd "insmod ${module_name} done"
			fi
			return 0
		fi
	}; done

	# In case file system isn't ready, try again
	qlog_cmd "can't find ${1}.ko, try again"
	module_name=/lib/modules/`uname -r`/extra/${1}.ko
	insmod ${module_name}
	qlog_cmd "insmod ${module_name} done"
}

rmmod_cmd() {

	local module_name="${1}"

	rmmod ${module_name}
	if [ ${module_name} = "wlan" ]; then
		restore_ini_file
	fi

	qlog_cmd "rmmod ${module_name} done"
}

update_wlan_config()
{
	check_concurrency_mode
	check_ipa_dynamic_ini
	if ([ $bridge_mode_enable = "enable" ] || [ $ipa_dynamic_ini_enable = "enable" ]); then
		backup_ini_file
		if [ $bridge_mode_enable = "enable" ]; then
			update_ini_file gIPAConfig 0
			update_ini_file hostArpOffload 0
			update_ini_file hostNSOffload 0
		fi
		if [ $ipa_dynamic_ini_enable = "enable" ]; then
			update_ini_file gIPAConfig 0x6d
			if [ $ipa_dynamic_ini_tx_ring_enable = "enable" ]; then
				update_ini_file dp_ipa_tx_ring_size 6144
				update_ini_file dp_ipa_tx_comp_ring_size 6144
			fi
		fi
	fi
	# bridge_mode_enable and ezmesh shouldn't
	# enable at same time
	update_ezmesh_ini
}

get_config_file_path_qcacld32() {
	echo "$wlan_ini_path$wlan_ini_name"
}

function update_ini_file()
{
	local ini_path=$(get_config_file_path_qcacld32)

	qlog_cmd "update ini file, $1=$2"
	#local end_line = grep -n END $ini_path | head -1 | cut -d ":" -f 1
	update_ini_cmd="grep -q $1 $ini_path && sed -i '/$1=/c $1=$2' $ini_path || sed -i '3i $1=$2' $ini_path"
	eval $update_ini_cmd
	qlog_cmd "$update_ini_cmd"
	sync
}

# No permission to run 'sed -i' with specific files on some platform.
# E.g. sdx65's files in folder '/etc/misc/wifi'. Since all of them are
# mountpoint and can't be rename. So cp the file to /tmp and then run
# 'sed -i', cp it back once update done.
function update_ini_file_by_tmp()
{
	local ini_path=$(get_config_file_path_qcacld32)
	local tmp_ini_path="/tmp/$wlan_ini_name"

	qlog_cmd "update ini file, $1=$2"
	#local end_line = grep -n END $ini_path | head -1 | cut -d ":" -f 1
	qlog_cmd "qcdbg, ini_path=$ini_path tmp_ini_path=$tmp_ini_path"
	cp $ini_path $tmp_ini_path
	update_ini_cmd="grep -q $1 $tmp_ini_path && sed -i '/$1=/c $1=$2' $tmp_ini_path || sed -i '3i $1=$2' $tmp_ini_path"
	eval $update_ini_cmd
	qlog_cmd "$update_ini_cmd"
	cp $tmp_ini_path $ini_path
	rm $tmp_ini_path
	sync
}

backup_ini_file() {
	if [ -f $wlan_ini_backup_path/$wlan_ini_name ]; then
		# For abnormal case like power off, avoid to duplicate backup
		qlog_cmd "$wlan_ini_backup_path/$wlan_ini_name exist"
	else
		cp $wlan_ini_path$wlan_ini_name $wlan_ini_backup_path
		qlog_cmd "cp $wlan_ini_path$wlan_ini_name $wlan_ini_backup_path"
	fi
}

restore_ini_file() {
	if [ -f $wlan_ini_backup_path/$wlan_ini_name ]; then
		if [ $yocto_build -eq 1 ]; then
			# sdx65's ini patch doesn't support 'mv' since it's a mountpoint
			cp $wlan_ini_backup_path/$wlan_ini_name $wlan_ini_path$wlan_ini_name
			rm $wlan_ini_backup_path/$wlan_ini_name
			qlog_cmd "cp $wlan_ini_backup_path/$wlan_ini_name $wlan_ini_path$wlan_ini_name"
		else
			cat $wlan_ini_backup_path/$wlan_ini_name > $wlan_ini_path$wlan_ini_name
			qlog_cmd "mv $wlan_ini_backup_path/$wlan_ini_name $wlan_ini_path$wlan_ini_name"
		fi
	fi
}

iw() {
	qlog_cmd iw "$@"
	/usr/sbin/iw "$@"
}

wlanconfig() {
	qlog_cmd wlanconfig "$@"
	/usr/sbin/wlanconfig "$@"
}

iwpriv() {
	qlog_cmd iwpriv "$@"
	/usr/sbin/iwpriv "$@"
}

ifconfig() {
	qlog_cmd ifconfig "$@"
	/sbin/ifconfig "$@"
}

wpa_cli() {
	qlog_cmd wpa_cli "$@"
	/usr/sbin/wpa_cli "$@"
}

hostapd_cli() {
	qlog_cmd hostapd_cli "$@"
	/usr/sbin/hostapd_cli "$@"
}

retry_cmd() {
	local n=1
	local delay=0.05
	local max=200

	while true; do
	("$@" &> /dev/null) && break || {
		if [[ $n -lt $max ]]; then
			[ `expr $n % 40` -eq 0 ] && qlog_cmd "Command $@ failed. Retry $n/$max:"
			((let n++))
			sleep $delay
		 else
			qlog_cmd "Command $@ has failed after $n retries."
			return 1
		fi
	}
	done

	qlog_cmd "Command $@ has succeed after $n retries"
	return 0
}


tmp_retry_cmd() {
	local n=1
	local delay=0.05
	local max=60

	while true; do
	("$@" &> /dev/null) && break || {
		if [[ $n -lt $max ]]; then
			[ `expr $n % 40` -eq 0 ] && qlog_cmd "Command $@ failed. Retry $n/$max:"
			((let n++))
			sleep $delay
		 else
			qlog_cmd "Command $@ has failed after $n retries."
			return 1
		fi
	}
	done

	qlog_cmd "Command $@ has succeed after $n retries"
	return 0
}

iface_set_up() {
	local iface=$1
	ifconfig $iface up
	[ -z "$(echo `ifconfig $iface | grep UP`)" ] && return 1
	return 0
}

iface_is_exist() {
	local iface=$1
	[ -z "$(echo `ifconfig -a | grep $iface`)" ] && return 1
	return 0
}

get_ezmesh_enable() {
	local ezmesh_enable

	# repacd.repacd.Ezmesh='0|1'
	config_load repacd
	config_get ezmesh_enable repacd Ezmesh 0

	echo $ezmesh_enable
}

is_hostapd_global_started() {
	if [ -r ${wlan_module_path}/hostapd-global.pid ]; then
		qlog_cmd "hostapd-global started return 0, pid=`cat ${wlan_module_path}/hostapd-global.pid`"
		return 0
	fi
	return 1
}

start_hostapd_global() {
	if [ $yocto_build -eq 1 ]; then
		if is_force_hostapd_attach && [ ! -e ${wlan_module_path}/hostapd-global.pid ]; then
			/usr/sbin/hostapd -g ${wlan_module_path}/${hostapd_global_ctrl_interface} -B \
			-P ${wlan_module_path}/hostapd-global.pid -dddd \
			-f ${wlan_module_path}/hostapd-global.log
		fi
	else
		if [ -f /etc/init.d/hostapd-global.init ]; then
			/etc/init.d/hostapd-global.init start &> /dev/kmsg
		else
			qlog_cmd "hostapd-global start fail due to init missing"
		fi
		tmp_retry_cmd is_hostapd_global_started
	fi
}

stop_hostapd_global() {
	if [ $yocto_build -eq 1 ]; then
		if is_force_hostapd_attach && [ -e ${wlan_module_path}/hostapd-global.pid ]; then
			wpa_cli -g ${wlan_module_path}/${hostapd_global_ctrl_interface} raw TERMINATE &> /dev/kmsg
		fi
	else
		if [ -r ${wlan_module_path}/hostapd-global.pid ]; then
			qlog_cmd "Stop hostapd-global pid=$(cat $wlan_module_path/hostapd-global.pid)"
			wpa_cli -g ${wlan_module_path}/${hostapd_global_ctrl_interface} raw TERMINATE &> /dev/kmsg
			/etc/init.d/hostapd-global.init stop &> /dev/kmsg
		fi
	fi
}

vif_is_started() {
	local iface=$1
	[ -z "$(echo `iw dev $iface info | grep ssid`)" ] && return 1
	return 0
}

get_vif() {
	[ -e /lib/functions.sh ] && . /lib/functions.sh
	wifi_dev=$1
	local vifs1=

	DEVICES=
		config_cb() {
			local type="$1"
			local section="$2"

			config_get device1 "$CONFIG_SECTION" device
			# Make sure each vif for $wifi_dev is processed only once
			if [ "$device1" == "$wifi_dev" ] && [ "$config_bkp" != "$CONFIG_SECTION" ]; then
				config_get TYPE "$CONFIG_SECTION" TYPE
				case "$TYPE" in
					wifi-iface)
						append vifs1 "$CONFIG_SECTION"
						vif=$vifs1
					;;
				esac
			# Hold the config item that has been processed
			config_bkp=$CONFIG_SECTION
			fi
		}
	config_load wireless
}

add_iface_to_network_config() {
	local device
	local vif vifs
	local disabled wlan_ifname network
	local dev_count=0
	local ifname_list="$(uci get network.lan.ifname)"
	local ifname_list_tmp=""
	local port_list="$(uci get network.br_lan.ports)"

	uci delete network.lan.ifname
	uci delete network.br_lan.ports

	for ifname in $port_list; do
		if ! echo "$ifname" | grep -q "wlan"; then
			uci add_list network.br_lan.ports="$ifname"
		fi
	done
	for ifname in $ifname_list; do
		if ! echo "$ifname" | grep -q "wlan"; then
			append ifname_list_tmp "$ifname"
		fi
	done
	uci set network.lan.ifname="$ifname_list_tmp"
	uci commit network

	for device in $DEVICES; do
		config_get disabled "$device" disabled 0
		[ $disabled -eq 0 ] || continue

		config_get vifs "$device" vifs
		for vif in $vifs; do
			config_get disabled "$vif" disabled 0
			[ $disabled -eq 0 ] || continue

			config_get wlan_ifname "$vif" ifname
			config_get network "$vif" network

			# OWRT V24 replaces 'option ifname' with 'list ports'
			if [ "$network" = "lan" ]; then
				if [ -z "$(uci get network.br_$network.ports | grep $wlan_ifname)" ]; then
					uci add_list network.br_$network.ports="$wlan_ifname"
				fi
				if [ -z "$(uci get network.$network.ifname | grep $wlan_ifname)" ]; then
					ifname_list_tmp="$(uci get network.$network.ifname)"
					append ifname_list_tmp "$wlan_ifname"
					uci set network.lan.ifname="$ifname_list_tmp"
				fi
				uci commit network
			elif [ "$network" = "backhaul" ]; then
				local map_version map_ts_enabled num_vlan
				local nw_name vlan_id
				local no_ifname no_eth eth_ifname nw_ifname_list

				config_load repacd
				config_get map_version MAPConfig 'MapVersionEnabled'
				config_get map_ts_enabled MAPConfig 'MapTrafficSeparationEnable' '0'
				config_get num_vlan MAPConfig 'NumberOfVLANSupported' '0'

				if [ $map_version -ge 2 -a $map_ts_enabled -eq 1 ]; then
					config_get vlan_id MAPConfig "VlanIDNwPrimary" '0'

					if [ -z "$(uci get network.br_lan.ports | grep $wlan_ifname.$vlan_id)" ]; then
						uci add_list network.br_lan.ports="$wlan_ifname.$vlan_id"
					fi
					if [ -z "$(uci get network.lan.ifname | grep $wlan_ifname.$vlan_id)" ]; then
						ifname_list_tmp="$(uci get network.lan.ifname)"
						append ifname_list_tmp "$wlan_ifname.$vlan_id"
						uci set network.lan.ifname="$ifname_list_tmp"
					fi
					uci commit network

					for i in One Two Three; do
						nw_ifname_list=""

						config_get nw_name MAPConfig "VlanNetwork"$i '0'
						config_get vlan_id MAPConfig "VlanIDNw"$i '0'

						if [ "$num_vlan" -eq 1 ]; then
							break
						fi

						if [ "$vlan_id" -eq 0 ]; then
							return
						fi

						# clear network.${nw_name}.ifname in the first loop
						if [ $dev_count -eq 0 ]; then
							uci delete network.${nw_name}.ifname
							uci commit network
						fi

						# if network.${nw_name}.ifname is empty or does not contain eth
						# interfaces, get eth interfaces from network.lan.ifname and
						# add related eth vlan interfaces to network.${nw_name}.ifname
						# for OWRT V24, add eth vlan interfaces to network.br_${nw_name}.ports
						no_ifname="$(echo `uci get network.${nw_name}.ifname | grep "Entry not found"`)"
						no_eth="$(echo `uci get network.${nw_name}.ifname | grep eth`)"
						if [ -n "$no_ifname" ] || [ ! -n "$no_eth" ]; then
							eth_ifname_list="$(echo `uci get network.lan.ifname | sed "s/wlan*.*//g" | xargs`)"
							if [ -n "$eth_ifname_list" ]; then
								for eth_ifname in $eth_ifname_list; do
									append nw_ifname_list "$eth_ifname.$vlan_id"
									if [ -z "$(uci get network.br_${nw_name}.ports | grep $eth_ifname.$vlan_id)" ]; then
										uci add_list network.br_${nw_name}.ports="$eth_ifname.$vlan_id"
									fi
								done
								uci set network.${nw_name}.ifname="$nw_ifname_list"
								uci commit network
							fi
						fi

						# for OWRT V24, add wlan vlan interfaces to network.br_${nw_name}.ports
						if [ -z "$(uci get network.br_${nw_name}.ports | grep $wlan_ifname.$vlan_id)" ]; then
							uci add_list network.br_${nw_name}.ports="$wlan_ifname.$vlan_id"
						fi

						# add wlan vlan interfaces to network.${nw_name}.ifname
						no_ifname="$(echo `uci get network.${nw_name}.ifname | grep "Entry not found"`)"
						if [ -n "$no_ifname" ]; then
							nw_ifname_list="$wlan_ifname.$vlan_id"
						else
							nw_ifname_list="$(echo `uci get network.${nw_name}.ifname`)"
							append nw_ifname_list "$wlan_ifname.$vlan_id"
						fi
						uci set network.${nw_name}.ifname="$nw_ifname_list"
						uci commit network

						num_vlan=$((num_vlan-1))
					done
				fi
			else
				if [ -z "$(uci get network.br_$network.ports | grep $wlan_ifname)" ]; then
					uci add_list network.br_$network.ports="$wlan_ifname"
				fi
				if [ -z "$(uci get network.$network.ifname | grep $wlan_ifname)" ]; then
					ifname_list_tmp="$(uci get network.$network.ifname)"
					append ifname_list_tmp "$wlan_ifname"
					uci set network.$network.ifname="$ifname_list_tmp"
				fi
				uci commit network
			fi
		done
		dev_count=$((dev_count+1))
	done

	ubus call network reload
}

update_backhaul_bss_info() {
	local device
	local vif vifs

	for device in $DEVICES; do
		config_get disabled "$device" disabled 0
		[ $disabled -eq 0 ] || continue

		config_get vifs "$device" vifs
		for vif in $vifs; do
			config_get disabled "$vif" disabled 0
			[ $disabled -eq 0 ] || continue

			config_get MapBSSType "$vif" MapBSSType 0
			# MapBSSType=64: backhaul BSS
			if [ $(($((MapBSSType&64)) >> 6)) -eq 1 ]; then
				# backhaul BSS configured
				backhaul_BSS=1
				config_load repacd
				config_get backhaul_ssid MAPConfig 'BackhaulSSID' ''
				config_get backhaul_key MAPConfig 'BackhaulKey' ''
				break
			fi
		done

		[ -n $backhaul_BSS ] && [ $backhaul_BSS -eq 1 ] && break
	done
}

dpp_set_channel() {
	local ifname device hwmode
	local map_version onboarding_type dpp_configurator_band

	config_load repacd
	config_get map_version MAPConfig 'MapVersionEnabled'
	config_get onboarding_type MAPConfig 'OnboardingType' ''
	config_get dpp_configurator_band MAPConfig 'DPPConfiguratorBand' '5'

	if [ $map_version -ge 3 -a "$onboarding_type" = "dpp" ]; then
		ifname=$(ucitool get_fh_iface $dpp_configurator_band)
		device=$(ucitool get_device $ifname)
		hwmode=$(uci get wireless.${device}.hwmode)

		# As per Wi-Fi Easy Connect Specification section 6.2, DPP Presence
		# Announcement is sent on Channel 6 on 2.4 GHz or Channel 44/149 on 5 GHz.
		if echo "$hwmode" | grep -q "g"; then
			qlog_cmd "dpp_set_channel: set $device channel to 6"
			uci set wireless.${device}.channel=6
		else
			if [ $dpp_configurator_band -eq 5 ]; then
				qlog_cmd "dpp_set_channel: set $device channel to 149"
				uci set wireless.${device}.channel=149
			fi
		fi

		uci commit wireless
	fi
}

dpp_set_config() {
	local ifname device hwmode
	local map_version onboarding_type dpp_configurator_band

	config_load repacd
	config_get map_version MAPConfig 'MapVersionEnabled'
	config_get onboarding_type MAPConfig 'OnboardingType' ''
	config_get dpp_configurator_band MAPConfig 'DPPConfiguratorBand' '5'

	if [ $map_version -ge 3 -a "$onboarding_type" = "dpp" ]; then
		ifname=$(ucitool get_fh_iface $dpp_configurator_band)
		device=$(ucitool get_device $ifname)
		hwmode=$(uci get wireless.${device}.hwmode)

		if [[ $hwmode == "*g*" ]]; then
			qlog_cmd "dpp_set_config: set dpp_wps=1 on $ifname"
			hostapd_cli -i $ifname -p ${wlan_module_path}/hostapd-$device SET dpp_wps 1
		else
			if [ $dpp_configurator_band -eq 5 ]; then
				qlog_cmd "dpp_set_config: set dpp_wps=1 on $ifname"
				hostapd_cli -i $ifname -p ${wlan_module_path}/hostapd-$device SET dpp_wps 1
			fi
		fi
	fi
}

add_iface_to_bridge() {
	local config=$1
	local iface network disabled MapBSSType bridge
	local map_version map_ts_enabled

	config_get iface "$config" ifname
	config_get network "$config" network
	config_get disabled "$config" disabled '0'
	config_get MapBSSType "$config" MapBSSType '0'

	config_load repacd
	config_get map_version MAPConfig 'MapVersionEnabled'
	config_get map_ts_enabled MAPConfig 'MapTrafficSeparationEnable' '0'

	[ "$disabled" -gt 0 ] && return
	[ "$network" = "backhaul" ] && return
	[ $map_version -ge 2 -a $map_ts_enabled -gt 0 -a \
		$(($((MapBSSType&64)) >> 6)) -eq 1 ] && return

	if [ $yocto_build -eq 1 ]; then
		bridge=$network
	else
		bridge=br-${network}
	fi

	brctl addif $bridge $iface 2>/dev/null >/dev/null
	qlog_cmd "add $iface to $bridge"
}

# Used for multi_up case
start_mld_ap() {
	local mld_dev=$1
	local ldevice
	local device_2g_6g
	local device_5g
	local vifs

	scan_wifi

	# Always start 5GHz device the last to avoid CAC conflicts
	# which causes force SCC
	for device in $DEVICES; do
		config_get hwmode "$device" hwmode "any"
		config_get band "$device" band 0
		if [[ $hwmode == "*g*" ]] || [ $band -eq 3 ]; then
			append device_2g_6g "$device"
		else
			append device_5g "$device"
		fi
	done
	ldevice="${device_2g_6g:+$device_2g_6g }${device_5g:+$device_5g }"

	for device in $ldevice; do
		config_get vifs "$device" vifs
		for vif in $vifs; do
			config_get mld $vif mld
			if [ $mld = $mld_dev ]; then
				start_vifs_qcacld32 "$device" "$vif" ""
			fi
		done
	done
}

# Used for multi_down case
stop_mld_ap() {
	local mld_dev=$1
	local ldevice=$DEVICES
	local vifs
	local ifname
	uci set wireless.${mld_dev}.num_ready_link=0
	for device in $ldevice; do
		config_get vifs "$device" vifs
		for vif in $vifs; do
			config_get mld $vif mld
			if [ $mld = $mld_dev ]; then
				config_get ifname "$vif" ifname
				hostapd_teardown_vif $ifname
			fi
		done
	done
}

action_vif() {
	local action=$1
	local device=$2
	local vif=$3

	case "$action" in
		start)
			update_backhaul_bss_info
			if [ $(echo $device | grep -c "$mld_prefix") -eq 1 ]; then
				start_mld_ap $device
			else
				start_vifs_qcacld32 "$device" "$vif" ""
			fi
		;;
		stop)
			if [ $(echo $device | grep -c "$mld_prefix") -eq 1 ]; then
				stop_mld_ap $device
			else
				config_get ifname "$vif" ifname
				config_get mode "$vif" mode

				case "$mode" in
					ap)
						qlog_cmd "hostapd_teardown_vif $vif"
						hostapd_teardown_vif $ifname
					;;
					sta)
						qlog_cmd "wpa_supplicant_teardown_vif $vif"
						wpa_supplicant_teardown_vif $ifname
					;;
					*) ;;
				esac
				if [ $yocto_build -eq 1 ]; then
					ifconfig "$ifname" down
				fi
			fi
		;;
		*) ;;
	esac
}

reconf_qcacld32() {
	local device="$1"
	local action="restart"

	config_get vifs "$device" vifs
	qlog_cmd "enter reconf_qcacld32: device=$device, vifs=$vifs"

	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled -eq 1 ] && {
			qlog_cmd "reconf_qcacld32: $vif is disabled, skip"
			continue
		}

		action_vif $action $device $vif
	done

	qlog_cmd "exit reconf_qcacld32"
}

assign_vif_ifname() {
	local device="$1"
	local disabled ifname
	local processed_vifs=""
	local unused_ifnames
	local unused_ifcount=0
	local unused_name
	local tmp_ifnames
	local auto_idx
	local auto_assigned
	local wlandev_idx=${device#$wlandev_prefix}
	local max_wlandev=3
	local max_if_wlandev

	config_get vifs "$device" vifs
	qlog_cmd "enter assign_vif_ifname device=$device, vifs=$vifs"

	max_if_wlandev=$(echo "$vifs" | awk 'END{print NF}')

	# construct unused ifname list.
	# e.g., wifi0: wlan0, wlan1; wifi1: wlan2, wlan3; wifi2: wlan4, wlan5
	[ $wlandev_idx -ge 0 ] && [ $wlandev_idx -lt $max_wlandev ] && {
		auto_idx=$(($wlandev_idx * $max_if_wlandev))
		while [ $auto_idx -lt $(($wlandev_idx * $max_if_wlandev + $max_if_wlandev)) ]
		do
			append unused_ifnames "${wlanif_prefix}${auto_idx}"
			auto_idx=$(($auto_idx + 1))
			unused_ifcount=$(($unused_ifcount + 1))
		done
	}

	# pre-process vifs
	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		# Update unused wlan names based on UCI config
		config_get ifname "$vif" ifname
		if [ -n "$ifname" ] && [ ${ifname//[0-9]} != ${wlanif_prefix} ]; then
			# Reset invalid ifnames to empty (i.e. option ifname 'cfgxxxx')
			# it will auto reassigned a name from unused wlan names later.
			config_set "$vif" ifname ""
		else
			if list_contains unused_ifnames $ifname; then
				# echo "list contians ifname=$ifname"
				# remove wlan names assigned from allow list
				tmp_ifnames=""
				auto_idx=0
				for unused_name in $unused_ifnames; do
					if [ "$unused_name" != "$ifname" ]; then
						append tmp_ifnames "${unused_name}"
						auto_idx=$(($auto_idx + 1))
					else
						qlog_cmd "assign_vif_ifname $vif manual-used $ifname"
						uci set wireless.${vif}.ifname=$ifname
						uci rename wireless.${vif}=$ifname
						uci commit wireless
						config_load wireless
					fi
				done
				unused_ifnames=$tmp_ifnames
				unused_ifcount=$auto_idx
			fi
		fi
	done

	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		config_get ifname "$vif" ifname
		# /sbin/wifi appends one duplicated vif, so remove it here
		if list_contains processed_vifs $vif; then
			qlog_cmd "assign_vif_ifname $vif [$ifname] already processed -- skip"
			continue
		fi
		# ifname not set? auto-assigned a name from unused wlan names.
		[ -z "$ifname" ] && [ $unused_ifcount -gt 0 ] && {
			# remove wlan names assigned from allow list
			tmp_ifnames=""
			auto_idx=0
			auto_assigned=0
			for unused_name in $unused_ifnames; do
				if [ $auto_assigned -eq 0 ]; then
					config_set "$vif" ifname $unused_name
					uci set wireless.${vif}.ifname=$unused_name
					uci rename wireless.${vif}=$unused_name
					uci commit wireless
					config_load wireless
					qlog_cmd "assign_vif_ifname $vif auto-assign $unused_name"
					auto_assigned=1
				else
					append tmp_ifnames "${unused_name}"
					auto_idx=$(($auto_idx + 1))
				fi
			done
			unused_ifnames=$tmp_ifnames
			unused_ifcount=$auto_idx
		}

		# Filter out duplicated vifs
		append processed_vifs "$vif"
	done
}

scan_qcacld32() {
	local device="$1"
	local wds
	local adhoc sta ap monitor lite_monitor ap_monitor ap_smart_monitor mesh ap_lp_iot
	local disabled mode ifname
	local processed_vifs=""

	config_load wireless
	config_get vifs "$device" vifs
	qlog_cmd "enter scan_qcacld32 device=$device, vifs=$vifs"

	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		# /sbin/wifi appends one duplicated vif, so remove it here
		if list_contains processed_vifs $vif; then
			qlog_cmd "scan_qcacld32 $vif already processed -- skip"
			continue
		fi

		config_get mode "$vif" mode
		case "$mode" in
			adhoc|sta|ap|monitor|lite_monitor|wrap|ap_monitor|ap_smart_monitor|mesh|ap_lp_iot)
				append "$mode" "$vif"
			;;
			wds)
				config_get ssid "$vif" ssid
				[ -z "$ssid" ] && continue

				config_set "$vif" wds 1
				config_set "$vif" mode sta
				mode="sta"
				addr="$ssid"
				${addr:+append "$mode" "$vif"}
			;;
			*) echo "$device($vif): Invalid mode, ignored."; continue;;
		esac

		# Filter out duplicated vifs
		append processed_vifs "$vif"
	done

	case "${adhoc:+1}:${sta:+1}:${ap:+1}" in
		# valid mode combinations
		1::) wds="";;
		1::1);;
		:1:1)config_set "$device" nosbeacon 1;; # AP+STA, can't use beacon timers for STA
		:1:);;
		::1);;
		::);;
		*) echo "$device: Invalid mode combination in config"; return 1;;
	esac

	vifs="${ap:+$ap }${ap_monitor:+$ap_monitor }${mesh:+$mesh }${ap_smart_monitor:+$ap_smart_monitor }${wrap:+$wrap }${sta:+$sta }${adhoc:+$adhoc }${wds:+$wds }${monitor:+$monitor }${lite_monitor:+$lite_monitor }${ap_lp_iot:+$ap_lp_iot}"
	# trim ending white space
	vifs="$(echo $vifs|sed -e 's/ *$//g')"
	config_set "$device" vifs "$vifs"

	qlog_cmd "exit scan_qcacld32 device=$device, vifs=$vifs"
}

set_wlan0_defer() {
	local flag=$1

	if [ "$flag" = "true" ];then
		qlog_cmd "set wlan0 to defer"
		ubus call network.device set_state '{"name":"wlan0", "defer":true}'
		echo "1" >> ${wlan_module_path}/wlan0_defer
	elif [ "$flag" = "false" ];then
		if [ -f ${wlan_module_path}/wlan0_defer ];then
			qlog_cmd "disable wlan0 defer"
			ubus call network.device set_state '{"name":"wlan0", "defer":false}'
			rm -f ${wlan_module_path}/wlan0_defer
		else
			qlog_cmd "no wlan0_defer"
		fi
	fi
}

load_qcacld32() {
	qlog_cmd "enter *** load_qcacld32 ***"
	local device="$2"
	local ezmesh_enable="$(get_ezmesh_enable)"
	local wait_time=1

	for mod in $(cat ${lib_wifi_path}/qcacld32-modules); do
		if [ "$mod" = "wlan" ] || [ "$mod" = "wlan_rome" ];then
			set_wlan0_defer true
		fi
		if [ "$mod" = "wlan_son_cld" ]; then
			[ $ezmesh_enable -eq 0 ] && continue
			retry_cmd iface_is_exist "wlan0"
			retry_cmd iface_set_up "wlan0"
		fi

		[ -d /sys/module/${mod} ] || { \
			insmod_cmd ${mod} $device || { \
				lock -u ${wlan_moduel_path}wifilock
				echo "load mod = ${mod} failed"
				return 1
			}
			if [ "$mod" = "wlan" ] || [ "$mod" = "wlan_rome" ];then
				retry_cmd iface_is_exist "wlan0"
				retry_cmd iface_set_up "wlan0"
			fi
		}
	done

	if [ "${FORCE_USE_WLAN_CONFIG_TEMPLATE}" = "1" ];then
		if [ -e "/dev/wlan" ];then
			echo "ON" >> /dev/wlan
			qlog_cmd "write ON to /dev/wlan"
			[ ! -w "/dev/wlan" ] && qlog_cmd "/dev/wlan not writable"
		else
			qlog_cmd "/dev/wlan not exist"
		fi
	fi

	qlog_cmd "exit *** load_qcacld32 ***"
}

unload_qcacld32() {
	if [ "${FORCE_USE_WLAN_CONFIG_TEMPLATE}" = "1" ];then
		qlog_cmd "enter unload_qcacld32 in legacy test mode"
		if [ -e "/dev/wlan" ];then
			echo "OFF" >> /dev/wlan
			qlog_cmd "write OFF to /dev/wlan"
			[ ! -w "/dev/wlan" ] && qlog_cmd "/dev/wlan not writable"
		else
			qlog_cmd "/dev/wlan not exist"
		fi
	else
		qlog_cmd "enter unload_qcacld32"
		# Make sure wlan_son_cld is unloaded before unload wlan
		while [ -d /sys/module/wlan_son_cld ]; do
			rmmod_cmd wlan_son_cld 2>/dev/null >/dev/null
		done
		[ -d /sys/module/wlan ] && rmmod_cmd wlan
	fi
}

_disable_qcacld32() {
	local device="$1"
	local vifs_name="$2"
	local parent=
	local retval=0
	local recover=0
	local ezmesh_enable=

	qlog_cmd "enter _disable_qcacld32 device=$1 vifs_name=$2"
	if [ "$1" = "1" ]; then
		device="$2"
		vifs_name="$3"
		recover="$1"
	fi

	#Invoked from wifi_hw_mode script
	if [ "$3" = "1" ]; then
		vifs_name=
	fi

	echo "$DRIVERS disable radio $device" >/dev/console

	config_get phy "$device" phy

	if [ -z "$vifs_name" ]; then
		set_wifi_down "$device"
	else
		for vif in $vifs_name; do
			set_vifs_down $device $vif
		done
	fi

	include /lib/network
	cd /sys/class/net
	for dev in *; do
		#ezmesh vlan e.g. 'wlan1.10' shouldn't enter below logic
		if [ ${wlanif_prefix} = "${dev:0:4}" ] && [ ${#dev} == 5 ]; then
			local ifidx=${dev#$wlanif_prefix}
			qlog_cmd "dev=$dev, ifidx=$ifidx"
			hostapd_teardown_vif "$dev"
			wpa_supplicant_teardown_vif "$dev"
			ifconfig $dev down
			[ $ifidx = 0 ] || iw "$dev" del
		fi
	done
	stop_hostapd_global

	ezmesh_enable="$(get_ezmesh_enable)"
	if [ $yocto_build -eq 1 ]; then
		# Do not unload wlan modules when ezmesh is enabled on SDX65
		[ $ezmesh_enable -eq 1 ] && unload=0
	else
		unload=1
	fi

	if [ $unload -eq 1 ]; then
		unload_qcacld32
	else
		qlog_cmd "skip unload_qcacld32"
	fi

	rm -rf ${wlan_module_path}/wlan_mode_info

	return 0
}

destroy_vap() {
	local ifname="$1"
	ifconfig $ifname down
	iw $ifname del
}

disable_qcacld32() {
	qlog_cmd "enter disable_qcacld32, ${1}"
	if [ "$1" = "1" ]; then   #wifi_hw_mode only
		_disable_qcacld32 $@
	else
		lock ${wlan_module_path}/wifilock
		_disable_qcacld32 "$@"
		lock -u ${wlan_module_path}/wifilock
	fi
}

# This function handles below cmds
# wifi multi_up/multi_down <device> <interface> <interface> ... <device> <interface> <interface> ...
multi_radio_wifi_updown() {
	local device_idx=2
	local vif_idx=3
	local post_vif_idx
	local device
	local action
	local is_last_vif=0
	local arg_vif post_arg_vif
	local ezmesh_enable="$(get_ezmesh_enable)"
	local start_fronthaul=0
	local MapBSSType fh_ifname bh_ifname

	config_load wireless

	if [ "$1" = "multi_up" ]; then
		action="start"
	else
		action="stop"
	fi

	qlog_cmd "qcacld32: $@"
	while [ $device_idx -le ${#} ]; do
		eval "device=\$${device_idx}";

		if [ $(echo $device | grep -c "$mld_prefix") -eq 1 ]; then
			action_vif $action $device
			device_idx=$(($device_idx + 1))
			vif_idx=$(($vif_idx + 1))
			continue
		fi

		eval "arg_vif=\$${vif_idx}";

		while [ $(echo $arg_vif | grep -c "$wlanif_prefix") -eq 1 ]; do
			post_vif_idx=$(($vif_idx + 1))
			eval "post_arg_vif=\$${post_vif_idx}";
			# check whether this is the last vif of wifiX
			[ -n $post_arg_vif ] && \
				[ $(echo $post_arg_vif | grep -c "$wlandev_prefix") -eq 1 ] || \
				[ -z $post_arg_vif ] && is_last_vif=1

			# look for the interface to start/stop
			config_get vifs "$device" vifs
			# update concurrency mode for legacy usecase
			if [ "$action" = "start" ]; then
				get_device_concurrency_mode "$vifs"
			fi
			for vif in $vifs; do
				config_get ifname "$vif" ifname
				if [ "$arg_vif" = "$ifname" ]; then
					action_vif $action $device $vif

					config_get MapBSSType "$vif" MapBSSType
					if [ $(($((MapBSSType&64)) >> 6)) -eq 1 ]; then
						# ucitool get_iface will return fronthual ifname
						fh_ifname=$(ucitool get_iface $device)
						bh_ifname=$ifname
						if [ "$action" = "start" ]; then
							start_fronthaul=1
						fi
					fi
					break
				fi
			done

			# update multi_ap_backhaul_ssid and
			# multi_ap_backhaul_wpa_passphrase in fronthual
			# hostapd conf
			if [ $start_fronthaul -eq 1 ]; then
				config_get vifs "$device" vifs
				for vif in $vifs; do
					config_get ifname "$vif" ifname
					if [ "$fh_ifname" = "$ifname" ]; then
						action_vif "start" $device $vif
						if [ $yocto_build -eq 1 ]; then
							hostapd_teardown_vif $fh_ifname
							wpa_cli -g ${wlan_module_path}/${hostapd_global_ctrl_interface} raw ADD \
								bss_config=$fh_ifname:${wlan_module_path}/hostapd-$fh_ifname.conf &> /dev/null
							retry_cmd vif_is_started "$fh_ifname"
							wpa_cli -g ${wlan_module_path}/${hostapd_global_ctrl_interface} raw ADD \
								bss_config=$bh_ifname:${wlan_module_path}/hostapd-$bh_ifname.conf &> /dev/null
							retry_cmd vif_is_started "$bh_ifname"
						fi
						start_fronthaul=0
						break
					fi
				done
			fi

			[ $is_last_vif -eq 1 ] && {
				device_idx=$post_vif_idx
				vif_idx=$(($device_idx + 1))
				is_last_vif=0
				break
			}

			vif_idx=$(($vif_idx + 1))
			eval "arg_vif=\$${vif_idx}";
		done
	done

	if [ "$action" = "start" -a $ezmesh_enable -ne 0 ]; then
		post_qcacld32_ezmesh $1
	fi
}

set_default_if() {
	local ldevice="$1"
	for device in $ldevice; do (
		config_get vifs "$device" vifs
		for vif in $vifs; do
			local wlanmode
			config_get ifname "$vif" ifname
			config_get mode "$vif" mode
			qlog_cmd "vif=$vif, ifname=$ifname, mode=$mode"
			[ -z "$ifname" ] && continue
			if [ $ifname == "wlan0" ] && [ $mode == "ap" ]; then
				iw dev wlan0 set type __ap
				qlog_cmd "set wlan0 to __ap"
				return
			fi
		done
	); done
}

start_qcacld32() {
	local ldevice="$1"
	local vifs_name="$2"
	local device_2g_6g
	local device_5g
	# For txpower settings
	local txpower=
	local txpower_device=
	local txpower_vifs=
	local vif_txpower=
	local ezmesh_enable="$(get_ezmesh_enable)"
	local mld_list="$MLD_DEVICES"
	local repacd_manual_bring_up

	if [ -z "$ldevice" ]; then
		ldevice=$DEVICES
	fi
	qlog_cmd "enter start_qcacld32 ldevice=$ldevice"
	rm -rf ${wlan_module_path}/wlan_mode_info

	# For 6 AP case, need to set wlan0 to __ap mode. Otherwise, it
	# will occupy two interfaces as MLO STA.
	set_default_if $ldevice

	# For non-DFS AP + 5 GHz DFS AP cases, start non-DFS AP first to
	# avoid conflict with ongoing CAC (Channel Availability Check).
	for device in $ldevice; do
		config_get hwmode "$device" hwmode "any"
		config_get band "$device" band 0

		if echo "$hwmode" | grep -q "g" || [ $band -eq 3 ]; then
			append device_2g_6g "$device"
		else
			append device_5g "$device"
		fi
	done
	# reorder ldevice to let 2.4/6 GHz AP start first
	ldevice="${device_2g_6g:+$device_2g_6g }${device_5g:+$device_5g }"
	qlog_cmd "start_qcacld32 reordered ldevice=$ldevice"

	if [ $ezmesh_enable -ne 0 ]; then
		if [ $owrt_build -eq 1 ]; then
			add_iface_to_network_config
		fi
		update_backhaul_bss_info
		dpp_set_channel
		start_hostapd_global
	fi

	for mld in $mld_list; do
		uci set wireless.${mld}.num_ready_link=0
		uci set wireless.${mld}.has_6GHz_link=0
	done

	for device in $ldevice; do
		config_get vifs "$device" vifs
		for vif in $vifs; do
			config_get ifmld $vif mld
			if [ -n "$ifmld" ]; then
				config_get band "$device" band 0
				if [ $band -eq 3 ]; then
					uci set wireless.${ifmld}.has_6GHz_link=1
				fi
			fi
		done
	done

	config_load wireless
	for device in $ldevice; do (
		config_get disabled "$device" disabled 0
		[ "$disabled" = "1" ] && {
			echo "'$device' is disabled"
			continue
		}
		scan_qcacld32 $device
		assign_vif_ifname $device
		scan_qcacld32 $device
		config_get vifs "$device" vifs

		get_device_concurrency_mode "$vifs"

		# Record txpower_device since later script may change $device.
		txpower_device=$device

		qlog_cmd "device=$device, vifs=$vifs"
		for vif in $vifs; do
			local wlanmode
			# use single hostapd for mld
			config_get mld "$vif" mld
			if [ -n "$mld" ]; then
				is_hostapd_global_started
				if [ $? -eq 1 ]; then
					start_hostapd_global
				fi
			fi
			config_get ifname "$vif" ifname

			config_get mode "$vif" mode
			wlanmode=$mode
			config_get extap "$vif" extap
			qlog_cmd "extap=$extap"

			# Record txpower_vifs for AP mode
			[ "$wlanmode" = "ap" ] && wlanmode="__ap" && wlanmode_str="HOSTAP" && append txpower_vifs "$vif"
			[ "$wlanmode" = "sta" ] && wlanmode="managed" && wlanmode_str="STA"
			if [ ! -z $ifname ]; then
				echo "$ifname:wlanmode=$wlanmode_str" >> ${wlan_module_path}/wlan_mode_info
			fi
			if [ -z "$(echo `ifconfig -a | grep $ifname`)" ]; then
				qlog_cmd "add interface=$ifname, mode=$wlanmode"
				retry_cmd iface_set_up "wlan0"
				iw wlan0 interface add $ifname type $wlanmode
				#support extender ap & STA
				[ -n "$extap" ] && [ $wlanmode_str = "STA" ] && iw "$ifname" set 4addr on
				[ -z "$(echo `ifconfig -a | grep $ifname`)" ] && return 1
			fi

			if [ "$ifname" = "wlan0" ]; then
				iw dev $ifname set type $wlanmode
				qlog_cmd "change wlan0 type $wlanmode done"
				#support extender ap & STA
				[ -n "$extap" ] && [ $wlanmode_str = "STA" ] && iw "$ifname" set 4addr on
				set_wlan0_defer false
			else
				qlog_cmd "wlanmode=$wlanmode, ifname=$ifname"
			fi
			retry_cmd iface_set_up "$ifname"

			start_vifs_qcacld32 "$device" "$vif" "$vifs_name"
		done

		# TXPower settings
		for vif in $txpower_vifs; do
			config_get ifname "$vif" ifname
			config_get txpower "$txpower_device" txpower
			config_get vif_txpower "$vif" txpower
			# use txpower on vif to overwrte txpower on device.
			txpower="${txpower:-$vif_txpower}"
			[ -z "$txpower" ] || {
				# TXPower settings only work if vif is started
				tmp_retry_cmd vif_is_started "$ifname"
				iw "$ifname" set txpower fixed "${txpower%%.*}00"
			}
		done

	); done

	config_load 'repacd'
	config_get repacd_manual_bring_up repacd 'ManualBringUp' '0'
	config_get_bool map_lite_enabled MAPConfig 'EnableLiteMode' '0'

	if [ $ezmesh_enable -ne 0 ]; then
		if [ $owrt_build -eq 1 ] || \
			[ $yocto_build -eq 1 -a $repacd_manual_bring_up -eq 1 ] || \
			[ $yocto_build -eq 1 -a $map_lite_enabled -eq 1 ]; then
			config_load wireless
			config_foreach add_iface_to_bridge wifi-iface
		fi
	fi
}


enable_qcacld32() {
	local device="$1"
	local vifs_name="$2"
	local recover=0
	local wifi_hwm_script

	qlog_cmd "enter enable_qcacld32, ${1}"
	if [ "$1" = "1" ]; then
		device="$2"
		vifs_name="$3"
		recover="$1"
	fi
	qlog_cmd "enable_qcacld32, vifs_name=$vifs_name"
	#Invoked from wifi_hw_mode script
	if [ "$3" = "1" ]; then
		vifs_name=
		wifi_hwm_script="$3"
	fi

	for device in $ldevice; do (
		config_get disabled "$device" disabled 0
		[ "$disabled" = "1" ] && {
			echo "'$device' is disabled"
			continue
		}
		scan_qcacld32 $device
		assign_vif_ifname $device
		scan_qcacld32 $device
		config_get vifs "$device" vifs

		for vif in $vifs; do
			# Comment out mld check for now and reserve it for TODO: Multi-link
			#config_get ifmld "$vif" mld
			#if [ -z $ifmld ]; then
					start_vifs_qcacld32 "$device" "$vif" "$vifs_name"
			#fi
		done
	); done

	if [ ! -z "$vifs_name" ]; then
		if [ "$recover" != "1" ]; then
			lock ${wlan_module_path}/wifilock
		fi

		for vif in $vifs_name
		do
			enable_vifs_qcacld32 $recover $device $vif
		done


		if [ "$recover" != "1" ]; then
			lock -u ${wlan_module_path}/wifilock
		fi
		return 0
	fi

	echo "$DRIVERS: enable radio $1" >/dev/console

	load_qcacld32 $recover $device
}

enable_vifs_qcacld32() {
	local device="$2"
	local vifs_name="$3"
	local wifi_hwm_script=
	local recover="$1"
	local edge_ch_dep_applicable
	local all_vifs map_vif

	qlog_cmd "enter enable_vifs_qcacld32"
	#Invoked from wifi_hw_mode script
	if [ "$3" = "1" ]; then
		vifs_name=
		wifi_hwm_script="$3"
	fi

	if [ -z "$vifs_name" ]; then
		ifconfig "$phy" up
	fi

	for vif in $vifs; do
		local start_hostapd=

		config_get ifname "$vif" ifname
		if [ ! -z "$vifs_name" -a "$ifname" != "$vifs_name" ]; then
			continue
		fi

		config_get mode "$vif" mode
		config_get enc "$vif" encryption "none"

		case "$enc" in
			wep*|mixed*|psk*|wpa*|8021x)
				start_hostapd=1
				config_get key "$vif" key
			;;
		esac

		case "$mode" in
			ap|wrap)
				if [ -n "$start_hostapd" ] && [ $count -lt 2 ] && eval "type hostapd_config_multi_cred" 2>/dev/null >/dev/null; then
					hostapd_config_multi_cred "$vif"
					count=$(($count + 1))
				fi
				;;
		esac

		if [ ! -z "$vifs_name" ]; then
			break
		fi
	done

	echo "number of vifs: $vifs" >/dev/console

	for vif in $vifs; do
		config_get ifname "$vif" ifname
		if [ ! -z "$vifs_name" -a "$ifname" != "$vifs_name" ]; then
			continue
		fi

		local start_hostapd= vif_txpower= nosbeacon= wlanaddr=""
		local mld_mac_option=
		local wlanmode
		local is_valid_owe_group=0
		local is_valid_sae_group=0
		config_get ifname "$vif" ifname
		config_get ppe_vp "$vif" ppe_vp 0
		config_get enc "$vif" encryption "none"
		config_get eap_type "$vif" eap_type
		config_get mode "$vif" mode
		config_get force_tkip "$vif" force_tkip 0
		config_get mld "$vif" mld
		wlanmode=$mode
		pmode=$mode

		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		[ "$nosbeacon" = 1 ] || nosbeacon=""
		if [ -z "$recover" ] || [ "$recover" -eq "0" ]; then
			wlanconfig "$ifname" create wlandev "$phy" wlanmode "$pmode" ${wlanaddr:+wlanaddr "$wlanaddr"} ${nosbeacon:+nosbeacon} -cfg80211

			if [ -z mld ]; then
				echo "cfg80211: ifname: $ifname mode: $wlanmode cfgphy: $(cat /sys/class/net/$phy/phy80211/name)" >&2
				iw phy "$(cat /sys/class/net/$phy/phy80211/name)" interface add $ifname type $wlanmode
			else
				config_get mld_mac "$mld" mld_macaddr
				[ -z "$mld_mac" ] || mld_mac_option="mld_addr"
				echo "cfg80211: ifname: $ifname mode: $wlanmode cfgphy: $(cat /sys/class/net/$phy/phy80211/name) $mld_mac_option $mld_mac " >&2
				iw phy "$(cat /sys/class/net/$phy/phy80211/name)" interface add $ifname type $wlanmode $mld_mac_option $mld_mac
			fi
			[ $? -ne 0 ] && {
				echo "enable_vifs_qcacld32($device): Failed to set up $mode vif $ifname" >&2
				continue
			}
			config_set "$vif" ifname "$ifname"
		fi
		if [ $nss_wifi_olcfg != 0 ] && [ $ppe_vp == 1 ]; then
			echo "$ifname" > /proc/sys/nss/ppe_vp/create && echo "PPE VP enabled for $ifname" > /dev/console
		fi

		if [ ! -z "$vifs_name" ]; then
			break
		fi
	done
}

start_vifs_qcacld32() {
	local device="$1"
	local vifs_name="$3"
	local vif="$2"
	local flag=0
	local force_hostapd_attach=0
	local mld num_ready_link

	qlog_cmd "enter start_vifs_qcacld32, device=$1, vif=$2, vifs_name=$3"

	config_get ifname "$vif" ifname
	config_get mld "$vif" mld
	if [ -n "$mld" ]; then
		num_ready_link=$(uci get wireless.${mld}.num_ready_link)
	fi

	if [ ! -z "$vifs_name" ]; then
		for tmp_vap in $vifs_name; do
			if [ $tmp_vap = $ifname ]; then
				flag=1
				break
			else
				continue
			fi
		done
		if [ $flag = 0 ]; then
			return
		fi
	fi

	if is_force_hostapd_attach; then
		force_hostapd_attach=1
	fi
	config_set "$device" force_hostapd_attach "$force_hostapd_attach"

	local start_hostapd=
	config_get ifname "$vif" ifname
	config_get mode "$vif" mode
	config_get enc "$vif" encryption "none"
	config_get map "$vif" map 0
	config_get MapBSSType "$vif" MapBSSType 0

	config_get_bool disabled "$vif" disabled 0
	[ $disabled = 0 ] || return

	# Stop possible stale hostapd/wpa_supplicant on $ifname
	if [ -z "$mld" ] || [ "$num_ready_link" -eq 0 ]; then
		qlog_cmd "tear down $ifname before enable non-mld or mld first link"
		hostapd_teardown_vif "$ifname"
		wpa_supplicant_teardown_vif "$ifname"
	fi

	config_set "$vif" ifname "$ifname"

	local net_cfg bridge

	case "$enc" in
		wapi*)
			start_wapid=1
			config_get key "$vif" key
		;;
		*)
		# We start hostapd in open mode too
			start_hostapd=1
		;;
	esac

	case "$mode" in
		ap|wrap|ap_monitor|ap_smart_monitor|mesh|ap_lp_iot)
			if [ -n "$start_wapid" ]; then
				wapid_setup_vif "$vif" nl80211 || {
					echo "start_vifs_qcacld32($device): Failed to set up wapid for interface $ifname" >&2
					ifconfig "$ifname" down
					iw "$ifname" del
					return
				}
			fi

			if [ "$mode" == "ap_lp_iot" ]; then
				default_dtim_period=41
			else
				default_dtim_period=1
			fi
			config_get dtim_period "$vif" dtim_period
			if [ -z "$dtim_period" ]; then
				config_set "$vif" dtim_period $default_dtim_period
			fi

			if [ -n "$start_hostapd" ] && eval "type hostapd_setup_vif" 2>/dev/null >/dev/null; then
				# If the radio has a backhaul BSS configured, call hostapd_setup_vif() with the
				# backhaul BSS credentials, so that the backhaul BSS credentials get configured
				# for all fronthaul VAPS
				if [ ! -z $backhaul_BSS ]; then
					if [ $backhaul_BSS -eq 1 ]; then
						hostapd_setup_vif "$vif" nl80211 no_nconfig bBSS "$backhaul_ssid" "$backhaul_key" || {
						echo "start_vifs_qcacld32($device): Failed to set up hostapd for interface $ifname" >&2
						# make sure this wifi interface won't accidentally stay open without encryption
						ifconfig "$ifname" down
						iw "$ifname" del
						return
						}
					else
						hostapd_setup_vif "$vif" nl80211 no_nconfig || {
							echo "start_vifs_qcacld32($device): Failed to set up hostapd for interface $ifname" >&2
							# make sure this wifi interface won't accidentally stay open without encryption
							ifconfig "$ifname" down
							iw "$ifname" del
						return
						}

					fi
				else
					hostapd_setup_vif "$vif" nl80211 no_nconfig concurrency_mode "$concurrency_mode" || {
						echo "start_vifs_qcacld32($device): Failed to set up hostapd for interface $ifname" >&2
						# make sure this wifi interface won't accidentally stay open without encryption
						ifconfig "$ifname" down
						iw "$ifname" del
						return
					}
				fi
			fi

			# set map and MapBSSType after interface up
			[ $map -gt 0 ] && cfg80211tool_mesh $ifname map $map
			[ $MapBSSType -gt 0 ] && cfg80211tool_mesh $ifname MapBSSType $MapBSSType
		;;
		wds|sta)
			if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
					wpa_supplicant_setup_vif "$vif" nl80211  || {
					echo "start_vifs_qcacld32($device): Failed to set up wpa_supplicant for interface $ifname" >&2
					ifconfig "$ifname" down
					[ '$ifname'='wlan0' ] || iw "$ifname" del
					return
				}
			fi
		;;
		adhoc)
			if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
				wpa_supplicant_setup_vif "$vif" nl80211 || {
					echo "start_vifs_qcacld32($device): Failed to set up wpa"
					ifconfig "$ifname" down
					iw "$ifname" del
					return
				}
			fi
	esac

	ifconfig "$ifname" up

	set_wifi_up "$vif" "$ifname"
}

check_concurrency_mode() {
	local ldevice="$1"

	bridge_mode_enable="disable"

	if [ -z "$ldevice" ]; then
		ldevice=$DEVICES
	fi
	qlog_cmd "enter check_concurrency_mode ldevice=$ldevice"

	# Get concurrency mode
	concurrency_mode=""
	num_ap_mld_links=0

	for device in $ldevice; do
		config_get disabled "$device" disabled 0
		[ $disabled -eq 1 ] && {
			qlog_cmd "check_concurrency_mode: $device is disabled"
			continue
		}

		scan_qcacld32 $device
		config_get vifs "$device" vifs
		get_device_concurrency_mode "$vifs"

		# Get eht htmode
		device_eht_htmode=""
		config_get hwmode "$device" hwmode
		config_get htmode "$device" htmode
		get_device_eht_htmode "$hwmode" "$htmode"

		qlog_cmd "check_concurrency_mode: device=$device, concurrency_mode=${concurrency_mode}, device_eht_htmode=${device_eht_htmode}"
	done
}

get_device_eht_htmode() {
	local tmp_hwmode="$1"
	local tmp_htmode="$2"

	case "${tmp_hwmode}:${tmp_htmode}" in
		*bea:HT20|*bea:VHT20|*bea:HE20|*bea:EHT20)
			device_eht_htmode="eht20"
			;;
		*bea:HT40+|*bea:HT40-|*bea:HT40|*bea:VHT40|*bea:HE40|*bea:EHT40+|*bea:EHT40-|*bea:EHT40)
			device_eht_htmode="eht40"
			;;
		*bea:HT80|*bea:VHT80|*bea:HE80|*bea:EHT80)
			device_eht_htmode="eht80"
			;;
		*bea:HT160|*bea:VHT160|*bea:HE160|*bea:EHT160)
			device_eht_htmode="eht160"
			;;
		*bea:HT320|*bea:VHT320|*bea:HE320|*bea:EHT320)
			device_eht_htmode="eht320"
			;;
		*bea:*)
			device_eht_htmode="eht0"
			;;
		*)
			device_eht_htmode=""
			;;
	esac
}

get_device_concurrency_mode() {
	local vifs="$1"
	local mode_str=""
	local hyphen="-"

	for vif in $vifs; do
		config_get disabled "$vif" disabled 0
		[ $disabled -eq 1 ] && {
			qlog_cmd "get_device_concurrency_mode: $vif is disabled"
			continue
		}

		config_get mode "$vif" mode

		case "$mode" in
			ap|wrap|ap_monitor|ap_smart_monitor|mesh|ap_lp_iot)
				mode_str="${hyphen}AP"
				local mld=""
				config_get mld "$vif" mld
				if [ -n "$mld" ]; then
					num_ap_mld_links=$((num_ap_mld_links+1))
					for mld_dev in $mld_devices; do
						if [ "$mld_dev" == "$mld" ]; then
							mode_str=""
							break
						fi
					done
					append mld_devices "$mld"
				fi
			;;
			wds|sta)
				mode_str="${hyphen}STA"
				config_get network "$vif" network
				if [ $network == "lan" ];then
					qlog_cmd "bridge mode enabled"
					bridge_mode_enable="enable"
				fi
			;;
			*) ;;
		esac

		if [ -z "$concurrency_mode" ]; then
			concurrency_mode="${mode_str#$hyphen}"
		else
			concurrency_mode="${concurrency_mode}${mode_str}"
		fi
	done
}

update_ezmesh_ini() {
	local ezmesh_enable
	local update_ini_func

	ezmesh_enable="$(get_ezmesh_enable)"
	[ $ezmesh_enable -eq 0 ] && {
		return
	}

	if [ $yocto_build -eq 1 ]; then
		update_ini_func="update_ini_file_by_tmp"
	else
		update_ini_func="update_ini_file"
	fi

	backup_ini_file
	$update_ini_func gIPAWds 1
	$update_ini_func gPreferNonDfsChanOnRadar 1
	$update_ini_func gEnableDcs 3
	$update_ini_func dcs_coch_intfr_threshold 600
	$update_ini_func ssdp 0
	$update_ini_func sap_rrm_enable 1
	$update_ini_func wds_mode 1
	$update_ini_func roam_triggers 0x600
	$update_ini_func gIPAVlanEnable 1
}

check_ipa_dynamic_ini() {
	local tmp_concurrency="${concurrency_mode}"
	local tmp_eht_htmode="${device_eht_htmode}"
	local tmp_socid;
	local tmp_buildinfo;

	ipa_dynamic_ini_enable="disable"
	ipa_dynamic_ini_tx_ring_enable="disable"

	if [ $(cat ${lib_wifi_path}/qcacld32-modules | grep -c wlan_rome) = 1 ];then
		qlog_cmd "disable ipa dynamic ini on Rome";
		return
	fi

	tmp_buildinfo="$(echo `uname -r`)"
	if [[ "${tmp_buildinfo}" == *"perf"* ]]; then
		qlog_cmd "check_ipa_dynamic_ini check perf build Pass";
	else
		qlog_cmd "check_ipa_dynamic_ini not perf build, but $tmp_buildinfo"
		return
	fi

	if [ "${tmp_concurrency}" = "AP" ]; then
		qlog_cmd "check_ipa_dynamic_ini check AP only mode Pass"
		ipa_dynamic_ini_enable="enable"
	else
		qlog_cmd "check_ipa_dynamic_ini not AP only mode - but ${tmp_concurrency}";
		return
	fi

	#TBD: AP_MLD and legacy AP concurrency
	if ([ "${tmp_eht_htmode}" = "eht320" ] || ([ "${tmp_eht_htmode}" = "eht160" ] && [ "${num_ap_mld_links}" = 2 ])) ; then
		qlog_cmd "check_ipa_dynamic_ini check eht320/multi-link eht160 Pass"
		ipa_dynamic_ini_tx_ring_enable="enable"
	else
		qlog_cmd "check_ipa_dynamic_ini not eht320 or multi-link eht160, but $num_ap_mld_links $tmp_eht_htmode"
		return
	fi

	qlog_cmd "check_ipa_dynamic_ini enabled due to all check passed"
}

pre_qcacld32() {
	local action=${1}

	qlog_cmd "pre_qcacld32, action=${1}"

	case "$action" in
		disable)
			[ -f $WSPLCD_INIT ] && $WSPLCD_INIT stop
			[ -f $EZMESH_INIT ] && $EZMESH_INIT stop
		;;
		*)
		;;
	esac
	qlog_cmd "exit pre_qcacld32, action=${1}"
}

post_qcacld32() {
	local action=${1}
	local ezmesh_enable="$(get_ezmesh_enable)"

	qlog_cmd "enter post_qcacld32, action=${1}"
	config_get type "$device" type
	[ "$type" != "qcacld32" ] && return

	lock ${wlan_module_path}/wifilock

	case "${action}" in
		enable)
			if [ "$2" != "multi_up" ]; then
				start_qcacld32 "$2" "$3"
			fi
		;;
		enable_recover)
			if [ "$2" != "multi_up" ]; then
				start_qcacld32 "$2" "$3"
			fi
		;;
	esac

	if [ $ezmesh_enable -ne 0 ]; then
		post_qcacld32_ezmesh $action
	fi

	lock -u ${wlan_module_path}/wifilock
}

is_force_hostapd_attach() {
	local ezmesh_enable="$(get_ezmesh_enable)"
	local force_hostapd_attach

	if [ $owrt_build -eq 1 ]; then
		return 0
	else
		if [ $ezmesh_enable -ne 0 ]; then
			config_load repacd
			config_get_bool force_hostapd_attach repacd 'ForceHostapdAttach' '0'
			if [ $force_hostapd_attach -eq 1 ]; then
				return 0
			else
				return 1
			fi
		else
			return 1
		fi
	fi
}

ezmesh_create_vlan_interface() {
	config_load repacd
	config_get_bool manual_create_vlan_interface repacd 'ManualCreateVlanInterface' '0'
	config_get map_version MAPConfig 'MapVersionEnabled'
	config_get map_ts_enabled MAPConfig 'MapTrafficSeparationEnable' '0'
	config_get num_vlan_supported MAPConfig 'NumberOfVLANSupported' '0'

	if [ $map_version -ge 2 -a $map_ts_enabled -gt 0 \
		-a $manual_create_vlan_interface -eq 1 ]; then
		local num_vlan=$num_vlan_supported
		for i in Primary One Two Three; do
			if [ "$num_vlan" -eq 0 ]; then
				break
			fi

			config_get nw_name MAPConfig "VlanNetwork"$i '0'
			config_get vlan_id MAPConfig "VlanIDNw"$i '0'

			if [ "$i" != "Primary" ]; then
				brctl addbr $nw_name 2>/dev/null >/dev/null
			fi

			config_load wireless
			config_foreach __create_vlan_interface wifi-iface $nw_name $vlan_id

			num_vlan=$((num_vlan-1))
		done
	fi
}

__create_vlan_interface() {
	local config=$1
	local nw_name=$2
	local vlan_id=$3
	local iface disabled

	config_get iface "$config" ifname ''
	config_get network "$config" network ''
	config_get disabled "$config" disabled '0'

	[ "$disabled" -gt 0 ] && return
	[ -z "$iface" ] && return
	[ "$network" != "backhaul" ] && return

	ip link add link $iface name $iface.$vlan_id type vlan id $vlan_id
	ip link set dev $iface.$vlan_id up
	brctl addif $nw_name $iface.$vlan_id 2>/dev/null >/dev/null
}

check_iface_up_status() {
	local iface_list="$(echo `ls /sys/class/net | grep $wlanif_prefix | grep -v "\."`)"
	local iface_list_len=$(echo $iface_list | awk '{print NF}')
	local iface_up_count=0

	while [ $iface_up_count -lt $iface_list_len ]; do
		for i in $iface_list; do
			while [ -z "$(iw dev $i info | grep ssid)" ]; do
				sleep 0.5
			done
			qlog_cmd "$i is up"
			iface_up_count=$(($iface_up_count + 1))
		done
	done
}

post_qcacld32_ezmesh() {
	local action=$1
	local repacd_manual_bring_up

	qlog_cmd "enter post_qcacld32_ezmesh, action=$action"

	case "$action" in
	enable|multi_up)
		if [ $yocto_build -eq 1 ]; then
			ezmesh_create_vlan_interface
		fi

		if is_force_hostapd_attach; then
			check_iface_up_status
		fi

		dpp_set_config

		config_load 'repacd'
		config_get repacd_manual_bring_up repacd 'ManualBringUp' '0'

		if [ $yocto_build -eq 1 -a $repacd_manual_bring_up -eq 0 ]; then
			return
		fi

		config_load wireless
		config_foreach add_iface_to_bridge wifi-iface

		[ -f $HYFI_BRIDGING_INIT ] && $HYFI_BRIDGING_INIT start
		[ -f $WSPLCD_INIT ] && $WSPLCD_INIT restart

		# call ezmesh restart manually because ezmesh hotplug will not be triggered in
		# 1. multi_up
		# 2. yocto build
		if [ "$action" = "multi_up" -o $yocto_build -eq 1 ]; then
			[ -f $EZMESH_INIT ] && $EZMESH_INIT restart
		fi
		;;
	*) ;;
	esac
}

detect_qcacld32() {
	local network
	if [ $owrt_build -eq 1 ]; then
		network="lan"
	else
		network="bridge0"
	fi

	cat > /etc/config/wireless <<EOF

config wifi-device  wifi0
	option type     qcacld32
	option channel  auto
	option dbdc_enable 0
	# REMOVE THIS LINE TO ENABLE WIFI:
	option disabled 1

config wifi-iface
	option device   wifi0
	option ifname   wlan0
	option network  $network
	option mode     ap
	option encryption psk2+ccmp
	option athnewind 1
	option MapBSSType 32
	option map 1
	option ssid FHSSID_EXPT
	option key FHKEY_EXPT
	option wps_pbc 1
	option root_distance 0
	option interworking 1
	list anqp_elem 272:34108cfdf0020df1f7000000733000030101

config wifi-iface
	option device   wifi0
	option ifname   wlan1
	option network  $network
	option mode     ap
	option encryption psk2+ccmp
	option athnewind 1
	option MapBSSType 64
	option map 1
	option ssid BHSSID_EXPT
	option key BHKEY_EXPT
	option wps_pbc 0
	option root_distance 0
	option interworking 1
	list anqp_elem 272:34108cfdf0020df1f7000000733000030101

config wifi-device  wifi1
	option type     qcacld32
	option channel  auto
	option dbdc_enable 0
	# REMOVE THIS LINE TO ENABLE WIFI:
	option disabled 1

config wifi-iface
	option device   wifi1
	option ifname   wlan2
	option network  $network
	option mode     ap
	option encryption psk2+ccmp
	option athnewind 1
	option MapBSSType 32
	option map 1
	option ssid FHSSID_EXPT
	option key FHKEY_EXPT
	option wps_pbc 1
	option root_distance 0
	option interworking 1
	list anqp_elem 272:34108cfdf0020df1f7000000733000030101

config wifi-iface
	option device   wifi1
	option ifname   wlan3
	option network  $network
	option mode     ap
	option encryption psk2+ccmp
	option athnewind 1
	option MapBSSType 64
	option map 1
	option ssid BHSSID_EXPT
	option key BHKEY_EXPT
	option wps_pbc 0
	option root_distance 0
	option interworking 1
	list anqp_elem 272:34108cfdf0020df1f7000000733000030101

EOF
}

generate_default_wireless_config() {
	local device=$1

	qlog_cmd "enter generate_default_wireless_config"

	uci -q batch <<-EOF
		set wireless.${device}=wifi-device
		set wireless.${device}.type=qcacld32
		set wireless.${device}.hwmode=11axa
		set wireless.${device}.channel=auto
		set wireless.${device}.disabled=1

		set wireless.${device}_AP1=wifi-iface
		set wireless.${device}_AP1.device=${device}
		set wireless.${device}_AP1.network=lan
		set wireless.${device}_AP1.mode=ap
		set wireless.${device}_AP1.ssid=QsoftAP_5G
		set wireless.${device}_AP1.encryption=psk2+ccmp
		set wireless.${device}_AP1.key=1234567890
		set wireless.${device}_AP1.disabled=1
EOF
	uci -q commit wireless
}
