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
echo "########Prepare for the WLAN firmware & bdf file########"
mkdir -p /lib/firmware/qca6174
mkdir -p /lib/firmware/qcn7605
mkdir -p /lib/firmware/qca6390

ln -sf /firmware/image/bdwlan30.* /lib/firmware/qca6174/
ln -sf /firmware/image/qwlan30.bin  /lib/firmware/qca6174/
ln -sf /firmware/image/utf30.bin  /lib/firmware/qca6174/
ln -sf /firmware/image/otp30.bin  /lib/firmware/qca6174/

ln -sf /firmware/image/SBL_RDDM_RAM_MERGED_6390.wlanfw.eval_v1_TO.mbn  /lib/firmware/qca6390/amss.bin
ln -sf /firmware/image/bdwlan02.e01 /lib/firmware/qca6390/
ln -sf /firmware/image/bdwlan.elf /lib/firmware/qca6390/
ln -sf /firmware/image/m3.bin /lib/firmware/qca6390/

ln -sf /firmware/image/SBL_RDDM_RAM_MERGED_7605.wlanfw.eval_v1_TO_ll.mbn  /lib/firmware/qcn7605/amss.bin
ln -sf /firmware/image/bdwlan03.b01 /lib/firmware/qcn7605/bdwlan.bin

echo "##########Trying to load wlanhost driver ##########"
if (lspci -k|grep cnss_pci);then
	if (lspci -k|grep 1102);then
		echo "##########load qcn7605#############"
		modprobe qcn7605
	elif ((lspci -k|grep 003e) || (lspci -k|grep QCA6174));then
		echo "##########load qca6174#############"
		modprobe qca6174
	elif (lspci -k|grep 1101);then
		echo "##########load qca6390#############"
		modprobe qca6390
	else
		echo "##########load default wlan########"
		modprobe wlan
	fi
fi
echo "##########Load wlanhost driver done################"

