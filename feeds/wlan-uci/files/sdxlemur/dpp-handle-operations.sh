#!/bin/sh
#
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
#

[ -e /lib/functions.sh  ] && . /lib/functions.sh
[ -e /lib/wifi/dpp-operating-class-update ] && . /lib/wifi/dpp-operating-class-update

is_section_ifname() {
	local config="$1"
	local ifname=
	config_get ifname "$config" ifname
	[ "${ifname}" = "$2" ] && eval "$3=$config"
}

handle_dpp_hostapd() {
	local ifname device vif map
	local type=

	ifname="$1"
	device="$2"
	vif="$3"
	map="$4"

	config_get dpp_type "$vif" dpp_type "qrcode"
	config_get dpp_curve "$vif" dpp_curve
	config_get dpp_key "$vif" dpp_key
	config_get channel "$device" channel auto
	config_get hwmode "$device" hwmode auto
	config_get htmode  "$device" htmode auto
	config_get pkex_code "$vif" pkex_code
	config_get pkex_identifier "$vif" pkex_identifier
	config_get dpp_auth_role "$vif" dpp_auth_role "initiator"
	config_get dpp_freq "$vif" dpp_freq 0
	config_get dpp_chirp "$vif" dpp_chirp
	config_get dpp_mud_url "$vif" dpp_mud_url
	config_get dpp_over_tcp "$vif" dpp_over_tcp
	config_get band "$device" band 0
	type=$dpp_type
	dpp_type="type=$dpp_type"

	if [ -z $dpp_curve ]; then
		dpp_curve=
	else
		dpp_curve="curve=$dpp_curve"
	fi

	if [ -z $dpp_key ]; then
		dpp_key=
	else
		dpp_key="key=$dpp_key"
	fi

	if [ "$pkex_identifier" ]; then
		pkex_identifier="identifier=$pkex_identifier"
	fi

	if [ "$pkex_code" ]; then
		pkex_code="code=$pkex_code"
	fi

	if [ "${htmode}" == "auto" ]
	then
		case "$hwmode:$htmode" in
			*ng:*) htmode=HT20;;
			*na:*) htmode=HT40;;
			*ac:*) htmode=HT80;;
			*axg:*) htmode=HT20;;
			*beg:*) htmode=HT20;;
			*axa:*) htmode=HT80;;
			*bea:*) htmode=HT80;;
			*:*) htmode=HT20;
		esac
	fi

	if [ "$channel" == "auto" ]; then
		channel=
	else
		dpp_operating_class_setup "$htmode" "$channel" "$band"
		dpp_operating_class=$?
		echo "dpp_operating_class=$dpp_operating_class" > /dev/console
		channel="chan=$dpp_operating_class/$channel"
	fi

	run_hostapd_cli() {
		ifname=$1
		ctrl_path=$2
		arguments=$3
		hostapd_cli -i $ifname -p $ctrl_path $arguments
	}

	if [ -n "${force_hostapd_attach}" -a "${force_hostapd_attach}" -eq 1 ]; then
		pid=/var/run/hostapd_cli-$ifname.pid
		run_hostapd_cli $ifname "/var/run/hostapd-$device" "-P $pid -a /lib/wifi/dpp-hostapd-update-uci -B"
	fi

	run_hostapd_cli $ifname "/var/run/hostapd-$device" "DPP_CONTROLLER_STOP"

	hostapd_cli -i $ifname -p /var/run/hostapd-$device dpp_bootstrap_remove \*
	hostapd_cli -i $ifname -p /var/run/hostapd-$device dpp_pkex_remove \*
	hostapd_cli -i $ifname -p /var/run/hostapd-$device dpp_configurator_remove \*
	if [ "$map" -ge 3 -a $band -ne 3 ]; then
		run_hostapd_cli $ifname  "/var/run/hostapd-$device" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve $dpp_key"
	else
		run_hostapd_cli $ifname  "/var/run/hostapd-$device" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve  $channel mac=$(cat /sys/class/net/$ifname/address | sed 's/://g') $dpp_key"
	fi

	if [ "$dpp_mud_url" ]; then
		run_hostapd_cli $ifname "/var/run/hostapd-$device" "SET dpp_mud_url $dpp_mud_url"
	fi

	config_get dpp_controller "$vif" dpp_controller
	if [ -z "$dpp_controller" ] && [ -z "$map" ] && [ "$map" -eq 0 ]; then
		if [ "$dpp_auth_role" == "initiator" ]; then
			#Initiator configuration
			if [ "$dpp_over_tcp" ]; then
				tcp_addr="tcp_addr=$dpp_over_tcp"
			else
				tcp_addr=
			fi

			if [ "dpp_freq" -ne 0]; then
				neg_freq="neg_freq=$dpp_freq"
			else
				neg_freq=
			fi

			if [ "${type}" == "qrcode" ]
			then
				run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_auth_init peer=1 role=enrollee $neg_freq $tcp_addr"
			else
				run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_pkex_add own=1 $pkex_identifier role=enrollee $pkex_code $tcp_addr"
			fi
		else
			#Responder configuration
			if [ "dpp_over_tcp" -ne 0 ]; then
				run_hostapd_cli $ifname "/var/run/hostapd-$device" "DPP_CONTROLLER_START qr=single"
			fi

			if [ "${type}" == "qrcode" ]; then
				run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_listen $dpp_freq role=enrollee"
			else
				run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_pkex_add own=1 $pkex_identifier role=enrollee $pkex_code"
			fi

			if [ $dpp_chirp -eq 1 ]; then
				run_hostapd_cli $ifname "/var/run/hostapd-$device" "dpp_chirp own=1 iter=10 listen=$dpp_freq"
			fi

		fi
	fi
}

handle_dpp_wpa_supplicant() {
	local ifname device vif map
	local type=

	ifname="$1"
	device="$2"
	vif="$3"
	map="$4"

	config_get dpp_type "$vif" dpp_type "qrcode"
	config_get dpp_curve "$vif" dpp_curve
	config_get dpp_key "$vif" dpp_key
	config_get channel "$device" channel auto
	config_get htmode  "$device" htmode auto
	config_get hwmode "$device" hwmode auto
	config_get pkex_code "$vif" pkex_code
	config_get pkex_identifier "$vif" pkex_identifier
	config_get band "$device" band 0
	type=$dpp_type
	dpp_type="type=$dpp_type"

	if [ -z $dpp_curve ]; then
		dpp_curve=
	else
		dpp_curve="curve=$dpp_curve"
	fi

	if [ -z $dpp_key ]; then
		dpp_key=
	else
		dpp_key="key=$dpp_key"
	fi

	if [ "$pkex_identifier" ]; then
		pkex_identifier="pkex_identifier=$pkex_identifier"
	fi

	if [ "$pkex_code" ]; then
		pkex_code="pkex_code=$pkex_code"
	fi

	if [ "${htmode}" == "auto" ]
	then
		case "$hwmode:$htmode" in
			*ng:*) htmode=HT20;;
			*na:*) htmode=HT40;;
			*ac:*) htmode=HT80;;
			*axg:*) htmode=HT20;;
			*beg:*) htmode=HT20;;
			*axa:*) htmode=HT80;;
			*bea:*) htmode=HT80;;
			*:*) htmode=HT20;
		esac
	fi

	if [ "$channel" == "auto" ]; then
		channel=
	else
		dpp_operating_class_setup "$htmode" "$channel" "$band"
		dpp_operating_class=$?
		echo "dpp_operating_class=$dpp_operating_class" > /dev/console
		channel="chan=$dpp_operating_class/$channel"
	fi

	run_wpa_cli() {
		ifname=$1
		ctrl_path=$2
		arguments=$3
		wpa_cli -i $ifname -p $ctrl_path $arguments
	}

	if [ -n "${force_hostapd_attach}" -a "${force_hostapd_attach}" -eq 1 ]; then
		run_wpa_cli $ifname "/var/run/wpa_supplicant-$ifname" "-a /lib/wifi/dpp-supplicant-update-uci -B"
	fi

	wpa_cli -i $ifname -p /var/run/wpa_supplicant-$ifname dpp_bootstrap_remove \*
	wpa_cli -i $ifname -p /var/run/wpa_supplicant-$ifname dpp_pkex_remove \*
	wpa_cli -i $ifname -p /var/run/wpa_supplicant-$ifname dpp_configurator_remove \*
	if [ "$map" -ge 3 -a $band -ne 3 ]; then
		run_wpa_cli $ifname  "/var/run/wpa_supplicant-$ifname" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve $dpp_key"
	else
		run_wpa_cli $ifname  "/var/run/wpa_supplicant-$ifname" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve  $channel mac=$(cat /sys/class/net/$ifname/address | sed 's/://g') $dpp_key"
	fi

	if [ -z "$map" ] || [ "$map" -eq 0 ]; then
		if [ "${type}" == "qrcode" ]
		then
			run_wpa_cli $ifname "/var/run/wpa_supplicant-$ifname" "dpp_auth_init peer=1  role=enrollee"
		else
			run_wpa_cli $ifname "/var/run/wpa_supplicant-$ifname" "dpp_pkex_add own=1 $pkex_identifier role=enrollee $pkex_code"
		fi
	fi
}

# This function is used when hostapd and wpa_supplicant iface-attaches
# are offloaded to user-space applications like QCMAP in SDx
main() {
	vif=
	local device dpp map mode

	/sbin/wifi scan
	config_load wireless

	device=$(cat /sys/class/net/$IFNAME/parent)
	config_foreach is_section_ifname wifi-iface "$IFNAME" vif
	config_get mode "$vif" mode

	config_get dpp "$vif" dpp 0
	config_get map "$vif" map 0

	if [ "$dpp" -eq 1 ] || [ "$map" -ge 3 ]; then
		if [ "$mode" = "ap" ]; then
			handle_dpp_hostapd $IFNAME $device $vif $map
		elif [ "$mode" = "sta" ]; then
			handle_dpp_wpa_supplicant $IFNAME $device $vif $map
		fi
	fi
}

IFNAME="$1"

if [ -n "$IFNAME" ]; then
	main
fi
