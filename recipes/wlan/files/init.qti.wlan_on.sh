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

if [ -f /sys/devices/soc0/hw_platform ]; then
    soc_hwplatform=`cat /sys/devices/soc0/hw_platform`
    soc_subtypeid=`cat /sys/devices/soc0/platform_subtype_id`
    echo -n "hwplatform: $soc_hwplatform" > /dev/kmsg
    echo -n "subtypeid: $soc_subtypeid" > /dev/kmsg
fi

if [ "$soc_hwplatform" == "IDP" ] && [ "$soc_subtypeid" == "1" ]; then
	echo "##########loading cnss2############"
	modprobe cnss2 sdio_mode=1
	echo "##########loading wlan driver############"
	modprobe qca6574au-3
else
	############################################
	if (lsmod|grep cnss2);then
		echo "##########cnss2 already exist######"
	else
		echo "##########loading cnss2############"
		modprobe cnss2
	fi
	echo "##########load cnss2 done############"

	LSPCI=`lspci -k`
	if (echo -n $LSPCI|grep cnss_pci);then
		if (echo -n $LSPCI|grep 1102);then
			echo "##########load qca6595#############"
			modprobe qca6595
		elif ((echo -n $LSPCI|grep 003e) || (echo -n $LSPCI|grep QCA6174));then
			echo "##########load qca6574#############"
			modprobe qca6574
		elif (echo -n $LSPCI|grep 1101);then
			echo "##########load qca6696#############"
			modprobe qca6696
		elif (echo -n $LSPCI|grep 1103);then
			echo "##########load qca6490#############"
			modprobe qca6490
		elif (echo -n $LSPCI|grep 1107);then
			echo "##########load qca6797#############"
			modprobe qca6797
		else
			echo "##########load default wlan########"
			modprobe wlan
		fi
	fi
fi

echo "##########Load wlanhost driver done################"

