#!/bin/sh
# Copyright (c) 2020, The Linux Foundation. All rights reserved.
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
# Changes from Qualcomm Technologies, Inc. are provided under the following license:
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo -n "start to unload cnss2 module" > /dev/kmsg
LSPCI=`lspci -kn`
if (echo -n $LSPCI|grep cnss_pci);then
	echo -n "start to unlaod wlan driver before unload cnss2" > /dev/kmsg
	if (echo -n $LSPCI|grep 1102);then
		echo -n "unload qca6595" > /dev/kmsg
		rmmod qca6595
	elif ((echo -n $LSPCI|grep 003e) || (echo -n $LSPCI|grep QCA6174));then
		echo -n "unload qca6574" > /dev/kmsg
		rmmod qca6574
	elif (echo -n $LSPCI|grep 1101);then
		echo -n "unload qca6696" > /dev/kmsg
		rmmod qca6696
	elif (echo -n $LSPCI|grep 1103);then
		echo -n "unload qca6490" > /dev/kmsg
		rmmod qca6490
	elif (echo -n $LSPCI|grep 1112);then
		echo -n "unload wcn7760" > /dev/kmsg
		rmmod wcn7760
	else
		echo -n "unload default wlan" > /dev/kmsg
		rmmod wlan
	fi
	echo -n "Skip unloading cnss2" > /dev/kmsg
fi
echo -n "unload wlanhost driver done" > /dev/kmsg

