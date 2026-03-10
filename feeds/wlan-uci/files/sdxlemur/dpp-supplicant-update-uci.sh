#!/bin/sh
#
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
#

[ -e /lib/functions.sh ] && . /lib/functions.sh

IFNAME=$1
CMD=$2
CONFIG=$3
shift
shift
SSID=$@
PASS=$@

parent=$(cat /sys/class/net/${IFNAME}/parent)
pairwise=

is_section_ifname() {
	local config=$1
	local ifname
	config_get ifname "$config" ifname
	[ "${ifname}" = "$2" ] && eval "$3=$config"
}

hex2string()
{
	I=0
	while [ $I -lt ${#1} ];
	do
		echo -en "\x"${1:$I:2}
		let "I += 2"
	done
}

get_map_config() {
	local config="$1"
	local ifname
	config_get ifname "$config" ifname
	[ "${ifname}" = "$2" ] && config_get map "$config" map 0
}

is_map_config() {
	config_load wireless
	config_foreach get_map_config wifi-iface $1
}

get_pairwise() {
	if [ -f /sys/class/net/$parent/ciphercaps ]
	then
		cat /sys/class/net/$parent/ciphercaps | grep -i "gcmp"
		if [ $? -eq 0 ]
		then
			pairwise="CCMP CCMP-256 GCMP GCMP-256"
		else
			pairwise="CCMP"
		fi
	fi
}

sect=
dpp=
map=

/sbin/wifi scan
config_load wireless

config_foreach is_section_ifname wifi-iface $IFNAME sect
config_get dpp "$sect" dpp 0
config_get map "$sect" map 0

if [ "$dpp" -ne 1 ] && [ "$map" -lt 3 ]; then
	kill $(cat /var/run/wpa_cli-dpp-${IFNAME}.pid)
fi

case "$CMD" in
	DPP-CONF-RECEIVED)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME remove_network all
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME add_network
		get_pairwise
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 pairwise $pairwise
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 group "CCMP"
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 proto "RSN"
		;;
	DPP-CONFOBJ-AKM)
		encryption=
		sae=
		dpp=
		sae_require_mfp=
		ieee80211w=
		key_mgmt=
		is_map_config $IFNAME
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 multi_ap_profile $map
		if [ $map -gt 0 ]
		then
			wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 multi_ap_backhaul_sta 1
		fi
		case "$CONFIG" in
			dpp+psk+sae)
				key_mgmt="DPP SAE WPA-PSK"
				encryption="psk2+ccmp"
				sae=1
				dpp=1
				ieee80211w=1
				sae_require_mfp=1
				;;
			dpp+sae)
				key_mgmt="DPP SAE"
				encryption="ccmp"
				sae=1
				ieee80211w=2
				dpp=1
				;;
			dpp)
				key_mgmt="DPP"
				encryption="dpp"
				ieee80211w=2
				dpp=1
				sae=0
				;;
			sae)
				key_mgmt="SAE"
				encryption="ccmp"
				sae=1
				ieee80211w=2
				dpp=0
				;;
			psk+sae)
				key_mgmt="SAE WPA-PSK"
				encryption="psk2+ccmp"
				sae=1
				ieee80211w=1
				sae_require_mfp=1
				dpp=0
				;;
			psk)
				key_mgmt="WPA-PSK"
				encryption="psk2"
				ieee80211w=1
				dpp=0
				sae=0
				;;
		esac
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 ieee80211w $ieee80211w
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 key_mgmt $key_mgmt

		uci set wireless.${sect}.encryption=$encryption
		uci set wireless.${sect}.sae=$sae
		uci set wireless.${sect}.sae_require_mfp=$sae_require_mfp
		uci set wireless.${sect}.dpp=$dpp
		uci set wireless.${sect}.ieee80211w=$ieee80211w
		uci commit wireless
		;;
	DPP-CONFOBJ-SSID)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 ssid \""$SSID"\"

		uci set wireless.${sect}.ssid="$SSID"
		uci commit wireless
		;;
	DPP-CONNECTOR)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_connector $CONFIG
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 dpp_connector \"${CONFIG}\"

		uci set wireless.${sect}.dpp_connector=$CONFIG
		uci commit wireless
		;;
	DPP-1905-CONNECTOR)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_1905_connector $CONFIG

		uci set wireless.${sect}.dpp_1905_connector=$CONFIG
		uci commit wireless
		;;
	DPP-CONFOBJ-PASS)
		PASS_STR=$(hex2string $PASS)
		get_pairwise

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 psk \"${PASS_STR}\"
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 pairwise $pairwise

		uci set wireless.${sect}.key="$PASS_STR"
		uci commit wireless

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME dpp_bootstrap_remove \*
		;;
	DPP-CONFOBJ-PSK)
		PASS_STR=$(hex2string "$CONFIG")
		get_pairwise

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 psk $PASS_STR
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 pairwise $pairwise

		uci set wireless.${sect}.key=$PASS_STR
		uci commit wireless

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME dpp_bootstrap_remove \*
		;;
	DPP-C-SIGN-KEY)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_csign $CONFIG
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 dpp_csign $CONFIG

		uci set wireless.${sect}.dpp_csign=$CONFIG
		uci commit wireless
		;;
	DPP-PP-KEY)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_pp_key $CONFIG
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 dpp_pp_key $CONFIG

		uci set wireless.${sect}.dpp_pp_key=$CONFIG
		uci commit wireless
		;;
	DPP-NET-ACCESS-KEY)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_netaccesskey $CONFIG
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 dpp_netaccesskey $CONFIG

		uci set wireless.${sect}.dpp_netaccesskey=$CONFIG
		uci commit wireless

		wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME enable_network 0
		wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME save_config

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME disable
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME enable
		;;
esac
