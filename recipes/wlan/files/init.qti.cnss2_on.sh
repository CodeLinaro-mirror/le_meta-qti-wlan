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
#

if (lsmod|grep cnss2);then
	echo -n "cnss2 already exist" > /dev/kmsg
else
    case "$1" in
        qcmap)
            echo -n "cnss2 script called from: $1" > /dev/kmsg
            if [ $2 == "enable" ];then
                echo -n "start to load cnss2" > /dev/kmsg
                modprobe cnss2
            fi
            ;;
        cnss)
            echo -n "start to load cnss2 script from: $1" > /dev/kmsg

            if [ -f /sys/devices/soc0/hw_platform ]; then
                soc_hwplatform=`cat /sys/devices/soc0/hw_platform`
                soc_subtypeid=`cat /sys/devices/soc0/platform_subtype_id`
                echo -n "hwplatform: $soc_hwplatform" > /dev/kmsg
                echo -n "subtypeid: $soc_subtypeid" > /dev/kmsg
            fi

            if [ "$soc_hwplatform" == "ADP" ] || [ "$soc_hwplatform" == "TTP" ]; then
                # Check if device is standalone ADP/TTP
                if [ "$soc_subtypeid" == "0" ]; then
                    echo -n "standalone ADP/TTP -> load cnss2 module" > /dev/kmsg
                    modprobe cnss2
                # Check if device is ADP/TTP with PCIe fusion
                elif [ "$soc_subtypeid" == "1" ]; then
                    echo -n "ADP/TTP with PCIe fusion -> skip loading cnss2 module" > /dev/kmsg
                # Check if device is ADP/TTP with USB fusion
                elif [ "$soc_subtypeid" == "2" ]; then
                    echo -n "ADP/TTP with USB fusion -> load cnss2 module" > /dev/kmsg
                    modprobe cnss2
                # Check if device is ADP/TTP with Flashless PCIe fusion
                elif [ "$soc_subtypeid" == "3" ]; then
                    echo -n "ADP/TTP with Flashless PCIe fusion -> skip loading cnss2 module" > /dev/kmsg
                else
                    echo -n "Not supported CDT sub type id, QCMAP_CLI will load cnss2 in needed" > /dev/kmsg
                fi
            # For SA525/SA510 IDP board
            elif [ "$soc_hwplatform" == "IDP" ]; then
                echo -n "IDP -> load cnss2 module" > /dev/kmsg

                # Run the command and extract the line containing "Subtype:"
                subtype_line=$(cdt_tool.sh -r | grep "Subtype:")

                # Extract the value after "Subtype:"
                subtype_value=$(echo "$subtype_line" | awk -F'Subtype:' '{print $2}' | xargs)

                # Check the value and load the corresponding cnss2 mode
                case "$subtype_value" in
                  "00")
                    modprobe cnss2
                    ;;
                  "01")
                    modprobe cnss2 sdio_mode=1
                    ;;
                  *)
                    echo "Unknown subtype: $subtype_value"
                    ;;
                esac
            else
                echo -n "Not supported platform from CDT, QCMAP_CLI will load cnss2 in needed" > /dev/kmsg
            fi
            ;;
    esac
fi

exit 0
