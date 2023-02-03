#!/bin/sh
# Copyright (c) 2019, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of The Linux Foundation nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#






echo "##########Trying to load wlanhost driver ##########"

if (lsmod|grep cnss2);then
	echo "##########cnss2 already exist######"
else
	echo "##########loading cnss2############"
	modprobe cnss2
fi
echo "##########load cnss2 done############"
wpas_conf="/etc/misc/wifi/wpa_supplicant.conf"
if (lspci -k|grep cnss_pci);then
	if (lspci -k|grep 1102);then
		echo "##########load qca6595#############"
		modprobe qca6595
	elif ((lspci -k|grep 003e) || (lspci -k|grep QCA6174));then
		echo "##########load qca6574#############"
		modprobe qca6574
	elif (lspci -k|grep 1101);then
		echo "##########load qca6696#############"
		modprobe qca6696
	elif (lspci -k|grep 1103);then
		echo "##########load qca6490#############"
		mount -o remount,rw /
		if ( grep -c "wowlan_triggers=magic_pkt" $wpas_conf ); then
			echo "wow setting is present in wpa_supplicant.conf"
			break
		else
			sed -i '$a\wowlan_triggers=magic_pkt' $wpas_conf
			echo "adding wow setting in wpa_supplicant.conf"
		fi
		modprobe qca6490
	else
		echo "##########load default wlan########"
		modprobe wlan
	fi
fi
echo "##########Load wlanhost driver done################"

