#
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
#

#!/bin/sh

MAX_SIZE=$((1024 * 1024 * 10))

LOG_FILES="
/data/vendor/wifi/hostapd-wlan20.log
/data/vendor/wifi/hostapd-wlan21.log
/data/vendor/wifi/hostapd-wlan50.log
/data/vendor/wifi/hostapd-wlan51.log
/data/vendor/wifi/hostapd-wlan60.log
/data/vendor/wifi/hostapd-wlan61.log
/data/vendor/wifi/hostapd-global.log
"

for log_file in $LOG_FILES; do
    [ -f "$log_file" ] || continue

    size=$(wc -c < "$log_file" 2>/dev/null)

    if [ "$size" -gt "$MAX_SIZE" ]; then
        cp "$log_file" "$log_file.1" && : > "$log_file"
    fi
done

