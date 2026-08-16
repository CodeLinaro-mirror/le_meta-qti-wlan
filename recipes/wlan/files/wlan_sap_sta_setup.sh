# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#!/bin/sh
# ============================================================
# Unified WLAN bring-up/tear-down for SAP1/SAP2/SAP3 and STA1/STA2
# BusyBox-/bin/sh-compatible (no bashisms)
#
# Features:
#  - Step 1: Detect chip (HSP/HMT/ROME/GENOA) using lsmod; fallback to modprobe loop
#  - Step 2: Show current UP interfaces (wlan0..wlan4) mapped to STA/SAP roles
#  - Step 3: Bring up SAP/STA per CLI inputs (continues on failures)
#  - Stop specific interfaces via -stop SAPx,STAy (no driver reload)
#  - v6: OWE (Opportunistic Wireless Encryption) security mode for SAP and STA
#
# Mappings (hardcoded):
#   STA1=wlan0, STA2=wlan4
#   SAP1=wlan1, SAP2=wlan2, SAP3=wlan3
#
# Chip modules:
#   HSP=qca6490  (11ax: 2G 20/40MHz, 5G 20/40/80/160MHz, 6G 20/40/80/160MHz)
#   HMT=qca6797  (11be: 2G 20/40MHz, 5G 20/40/80/160MHz, 6G 20/40/80/160/320MHz)
#   ROME=qca6574 (11ac: 2G 20/40MHz, 5G 20/40/80MHz — no 6G)
#   GENOA=qca6595(11ac: 2G 20/40MHz, 5G 20/40/80MHz — no 6G)
#
# Config files (per-interface):
#   hostapd:       /data/hostapd_<iface>.conf       (e.g., /data/hostapd_wlan1.conf)
#   wpa_supplicant:/data/wpa_supplicant_<iface>.conf (e.g., /data/wpa_supplicant_wlan0.conf)
# ============================================================

# -------- Logging --------
DEBUG=0   # set to 1 via -d flag; enables command traces and verbose daemon output

info()  { echo "[INFO] $*"; }
warn()  { echo "[WARN] $*"; }
err()   { echo "[ERROR] $*" >&2; }
trace() { [ "$DEBUG" -eq 1 ] && echo "$*"; }   # debug-only command trace

die() { err "$*"; exit 1; }

# -------- Roles -> Interfaces (hardcoded) --------
STA1_IF="wlan0"
STA2_IF="wlan4"
SAP1_IF="wlan1"
SAP2_IF="wlan2"
SAP3_IF="wlan3"

# -------- Chip mapping (hardcoded) --------
HSP="qca6490"
HMT="qca6797"
ROME="qca6574"
GENOA="qca6595"

# PCI device IDs (vendor:device, lowercase) — verify vendor prefix matches your platform
HSP_PCI="17cb:1103"
HMT_PCI="17cb:1107"
ROME_PCI1="168c:003e"   # qca6574 variant 1
ROME_PCI2="168c:6174"   # qca6574 variant 2
GENOA_PCI="17cb:1102"

# Search order for modprobe fallback only
CHIP_ORDER="$HSP $HMT $ROME $GENOA"

# Will be set by detection
WLAN_CHIP_TYPE=""
WLAN_MODULE_NAME=""

# -------- Simple execution helpers --------
run_print() {
    trace "+ $*"
    sh -c "$*"
    return $?
}

safe_killall() {
    # killall <proc> non-fatal if not running
    p="$1"
    trace "+ (safe) killall $p"
    if command -v pidof >/dev/null 2>&1; then
        if pidof "$p" >/dev/null 2>&1; then
            killall "$p" >/dev/null 2>&1 || killall -9 "$p" >/dev/null 2>&1 || true
        fi
    else
        if ps -ef >/dev/null 2>&1; then
            if ps -ef | grep -v grep | grep -q "[/]$p"; then
                killall "$p" >/dev/null 2>&1 || killall -9 "$p" >/dev/null 2>&1 || true
            fi
        else
            if ps w 2>/dev/null | grep -v grep | grep -q "[/]$p"; then
                killall "$p" >/dev/null 2>&1 || killall -9 "$p" >/dev/null 2>&1 || true
            fi
        fi
    fi
}

iface_exists() {
    if [ -d "/sys/class/net/$1" ]; then return 0; fi
    if command -v ip >/dev/null 2>&1; then ip link show "$1" >/dev/null 2>&1 && return 0; fi
    if command -v ifconfig >/dev/null 2>&1; then ifconfig "$1" >/dev/null 2>&1 && return 0; fi
    return 1
}

iface_up() {
    if command -v ifconfig >/dev/null 2>&1; then ifconfig "$1" up >/dev/null 2>&1 && return 0; fi
    if command -v ip >/dev/null 2>&1; then ip link set dev "$1" up >/dev/null 2>&1 && return 0; fi
    return 1
}

iface_down() {
    trace "+ ifconfig $1 down"
    if command -v ifconfig >/dev/null 2>&1; then ifconfig "$1" down >/dev/null 2>&1 && return 0; fi
    if command -v ip >/dev/null 2>&1; then ip link set dev "$1" down >/dev/null 2>&1 && return 0; fi
    warn "Could not bring $1 down (neither ifconfig nor ip available)"
    return 1
}

iface_is_up() {
    IF="$1"
    if command -v ifconfig >/dev/null 2>&1; then
        ifconfig "$IF" 2>/dev/null | grep -q "RUNNING" && return 0
    fi
    if [ -r "/sys/class/net/$IF/operstate" ]; then
        STATE=$(cat "/sys/class/net/$IF/operstate" 2>/dev/null)
        [ "$STATE" = "up" ] && return 0
    fi
    return 1
}

# -------- Chip detection (Step 1) --------
detect_chip() {
    # Step 1: lsmod — driver already loaded, just identify it
    for mod in $CHIP_ORDER; do
        if lsmod 2>/dev/null | grep -q "^$mod"; then
            WLAN_MODULE_NAME="$mod"
            case "$mod" in
              "$HSP")   WLAN_CHIP_TYPE="HSP" ;;
              "$HMT")   WLAN_CHIP_TYPE="HMT" ;;
              "$ROME")  WLAN_CHIP_TYPE="ROME" ;;
              "$GENOA") WLAN_CHIP_TYPE="GENOA" ;;
            esac
            info "Detected WLAN chip (lsmod): type=$WLAN_CHIP_TYPE module=$WLAN_MODULE_NAME"
            return 0
        fi
    done

    # Step 2: lspci — identify hardware, then targeted single modprobe
    # Captures both 'lspci -n' (numeric: "17cb:1107") and plain 'lspci' ("Qualcomm Device 1107")
    if command -v lspci >/dev/null 2>&1; then
        LSPCI_ALL="$(lspci -n 2>/dev/null | tr 'A-Z' 'a-z')
$(lspci 2>/dev/null | tr 'A-Z' 'a-z')"
        for entry in "HSP|${HSP_PCI}|${HSP}" "HMT|${HMT_PCI}|${HMT}" "ROME|${ROME_PCI1}|${ROME}" "ROME|${ROME_PCI2}|${ROME}" "GENOA|${GENOA_PCI}|${GENOA}"; do
            chip_type=$(echo "$entry" | cut -d'|' -f1)
            pci_id=$(echo "$entry"   | cut -d'|' -f2)
            dev_id=$(echo "$pci_id"  | cut -d: -f2)   # e.g. "17cb:1107" -> "1107"
            mod=$(echo "$entry"      | cut -d'|' -f3)
            if echo "$LSPCI_ALL" | grep -q "$pci_id" || \
               echo "$LSPCI_ALL" | grep -q "device $dev_id" || \
               echo "$LSPCI_ALL" | grep -qi "$mod"; then
                info "Identified WLAN chip via lspci: type=$chip_type (PCI $pci_id) — loading $mod"
                trace "+ modprobe $mod"
                if modprobe "$mod" >/dev/null 2>&1; then
                    WLAN_MODULE_NAME="$mod"
                    WLAN_CHIP_TYPE="$chip_type"
                    info "Loaded WLAN driver via lspci+modprobe: type=$WLAN_CHIP_TYPE module=$WLAN_MODULE_NAME"
                    return 0
                else
                    err "modprobe $mod failed (chip identified as $chip_type via lspci)"
                    return 1
                fi
            fi
        done
        warn "lspci available but no known WLAN chip PCI ID matched — falling back to modprobe loop"
    else
        warn "lspci not available — falling back to modprobe loop"
    fi

    # Step 3: Last resort — try modprobe in order; first success wins
    for mod in $CHIP_ORDER; do
        trace "+ modprobe $mod"
        if modprobe "$mod" >/dev/null 2>&1; then
            WLAN_MODULE_NAME="$mod"
            case "$mod" in
              "$HSP")   WLAN_CHIP_TYPE="HSP" ;;
              "$HMT")   WLAN_CHIP_TYPE="HMT" ;;
              "$ROME")  WLAN_CHIP_TYPE="ROME" ;;
              "$GENOA") WLAN_CHIP_TYPE="GENOA" ;;
            esac
            info "Loaded WLAN driver via modprobe: type=$WLAN_CHIP_TYPE module=$WLAN_MODULE_NAME"
            return 0
        else
            warn "modprobe $mod failed (trying next)"
        fi
    done

    err "Could not determine/load any supported WLAN driver (HSP/HMT/ROME/GENOA)."
    return 1
}

reload_driver_if_requested() {
    REQ="$1"  # y|n
    if [ "$REQ" = "y" ]; then
        info "Reloading WLAN driver: stopping wifi processes and reloading $WLAN_MODULE_NAME"
        safe_killall wpa_supplicant
        safe_killall hostapd

        trace "+ rmmod $WLAN_MODULE_NAME"
        rmmod "$WLAN_MODULE_NAME" >/dev/null 2>&1 || true

        trace "+ modprobe $WLAN_MODULE_NAME"
        if ! modprobe "$WLAN_MODULE_NAME" >/dev/null 2>&1; then
            die "modprobe $WLAN_MODULE_NAME failed after detection"
        fi
        sleep 2
    else
        info "Driver reload not requested (-reload_driver n)"
    fi
}

unload_driver() {
    if [ -z "$WLAN_MODULE_NAME" ]; then
        err "Cannot unload: chip detection failed, WLAN_MODULE_NAME is not set"
        return 1
    fi
    info "Unloading WLAN driver: stopping wifi processes and removing $WLAN_MODULE_NAME"
    safe_killall wpa_supplicant
    safe_killall hostapd
    trace "+ rmmod $WLAN_MODULE_NAME"
    if rmmod "$WLAN_MODULE_NAME" >/dev/null 2>&1; then
        info "Successfully unloaded $WLAN_MODULE_NAME ($WLAN_CHIP_TYPE)"
    else
        err "rmmod $WLAN_MODULE_NAME failed — module may not be loaded or still in use"
        return 1
    fi
}

# -------- Visibility (Step 2): show interface status table --------
show_up_interfaces_table() {
    _wait_ip="${1:-}"   # pass "wait" to enable DHCP retry on final call

    # Wait once for all IPs together, before iterating per-interface
    if [ "$_wait_ip" = "wait" ]; then
        _ip_try=0
        while [ "$_ip_try" -lt 5 ]; do
            _all_have_ip=1
            for _wif in "$STA1_IF" "$SAP1_IF" "$SAP2_IF" "$SAP3_IF" "$STA2_IF"; do
                iface_exists "$_wif" || continue
                iface_is_up   "$_wif" || continue
                _a=$(ifconfig "$_wif" 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p' | head -n1)
                [ -z "$_a" ] && _a=$(ifconfig "$_wif" 2>/dev/null | sed -n 's/.*inet \([0-9.]*\) .*/\1/p' | head -n1)
                [ -z "$_a" ] && { _all_have_ip=0; break; }
            done
            [ "$_all_have_ip" -eq 1 ] && break
            _ip_try=$((_ip_try + 1))
            printf "\r  [INFO] Waiting for IP ... %ds/5s" "$_ip_try"
            sleep 1
        done
        [ "$_ip_try" -gt 0 ] && printf "\n"
    fi

    echo ""
    printf "%-6s  %-7s  %-6s  %-7s  %-10s  %-10s  %-20s  %s\n" \
        "Role" "Iface" "State" "Channel" "Freq(MHz)" "Width" "SSID / Link" "IP Address"
    printf "%-6s  %-7s  %-6s  %-7s  %-10s  %-10s  %-20s  %s\n" \
        "------" "-------" "------" "-------" "----------" "----------" "--------------------" "----------"
    shown=0
    for role_if in "STA1:${STA1_IF}:sta" "SAP1:${SAP1_IF}:ap" "SAP2:${SAP2_IF}:ap" "SAP3:${SAP3_IF}:ap" "STA2:${STA2_IF}:sta"; do
        role=$(echo "$role_if" | cut -d: -f1)
        ifc=$(echo "$role_if"  | cut -d: -f2)
        mode=$(echo "$role_if" | cut -d: -f3)
        iface_exists "$ifc" || continue
        shown=1

        state="DOWN"
        iface_is_up "$ifc" && state="UP"

        chan="-"; freq="-"; width="-"; detail="-"

        if command -v iw >/dev/null 2>&1; then
            if [ "$mode" = "ap" ]; then
                IW_OUT="$(iw dev "$ifc" info 2>/dev/null)"
                chan=$(echo "$IW_OUT"   | sed -n 's/.*channel \([0-9]*\) .*/\1/p'               | head -n1)
                freq=$(echo "$IW_OUT"   | sed -n 's/.*channel [0-9]* (\([0-9]*\) MHz.*/\1/p'   | head -n1)
                width=$(echo "$IW_OUT"  | sed -n 's/.*width: \([^,]*\).*/\1/p'                  | head -n1)
                detail=$(echo "$IW_OUT" | sed -n 's/^[[:space:]]*ssid //p'                      | head -n1)
                [ -z "$chan"   ] && chan="-"
                [ -z "$freq"  ] && freq="-"
                [ -z "$width" ] && width="-"
                [ -z "$detail" ] && detail="-"
            else
                IW_OUT="$(iw dev "$ifc" info 2>/dev/null)"
                chan=$(echo "$IW_OUT"   | sed -n 's/.*channel \([0-9]*\) .*/\1/p'               | head -n1)
                freq=$(echo "$IW_OUT"   | sed -n 's/.*channel [0-9]* (\([0-9]*\) MHz.*/\1/p'   | head -n1)
                width=$(echo "$IW_OUT"  | sed -n 's/.*width: \([^,]*\).*/\1/p'                  | head -n1)
                detail=$(echo "$IW_OUT" | sed -n 's/^[[:space:]]*ssid //p'                      | head -n1)
                [ -z "$chan"   ] && chan="-"
                [ -z "$freq"  ] && freq="-"
                [ -z "$width" ] && width="-"
                [ -z "$detail" ] && detail="Not connected"
            fi
        fi

        ip_addr=""
        ip_addr=$(ifconfig "$ifc" 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p' | head -n1)
        [ -z "$ip_addr" ] && ip_addr=$(ifconfig "$ifc" 2>/dev/null | sed -n 's/.*inet \([0-9.]*\) .*/\1/p' | head -n1)
        [ -z "$ip_addr" ] && ip_addr="-"

        printf "%-6s  %-7s  %-6s  %-7s  %-10s  %-10s  %-20s  %s\n" \
            "$role" "$ifc" "$state" "$chan" "$freq" "$width" "$detail" "$ip_addr"
    done
    [ "$shown" -eq 0 ] && echo "  (no interfaces present)"
    echo ""
}

# -------- SAP helpers --------
ensure_ap_interface() {
    PARENT="wlan0"  # create SAP from wlan0
    CHILD="$1"
    if iface_exists "$CHILD"; then
        info "$CHILD exists — bringing it UP"
        iface_up "$CHILD" || warn "Failed to bring $CHILD UP; continuing"
        return 0
    fi
    warn "$CHILD not found — creating from $PARENT as __ap"
    OUT="$(iw dev "$PARENT" interface add "$CHILD" type __ap 2>&1)"
    if [ $? -ne 0 ]; then
        echo "$OUT" | grep -qi "exists"
        if [ $? -eq 0 ]; then
            info "Interface $CHILD already exists (iw reported exists); proceeding"
        else
            err "Failed to create $CHILD: $OUT"
            return 1
        fi
    fi
    iface_up "$CHILD" || warn "Created $CHILD but failed to bring it UP"
    return 0
}

# Create a managed (STA) interface if missing, from wlan0
ensure_managed_interface() {
    CHILD="$1"         # e.g., wlan4
    PARENT="wlan0"     # base interface to clone from

    if iface_exists "$CHILD"; then
        info "$CHILD exists — bringing it UP"
        iface_up "$CHILD" || warn "Failed to bring $CHILD UP; continuing"
        return 0
    fi

    # If requested child is the parent itself, just bring it up
    if [ "$CHILD" = "$PARENT" ]; then
        info "$CHILD is the base interface — bringing it UP"
        iface_up "$CHILD" || warn "Failed to bring $CHILD UP; continuing"
        return 0
    fi

    warn "$CHILD not found — creating from $PARENT as managed"
    OUT="$(iw dev "$PARENT" interface add "$CHILD" type managed 2>&1)"
    if [ $? -ne 0 ]; then
        echo "$OUT" | grep -qi "exists"
        if [ $? -eq 0 ]; then
            info "Interface $CHILD already exists (iw reported exists); proceeding"
        else
            err "Failed to create $CHILD: $OUT"
            return 1
        fi
    fi

    iface_up "$CHILD" || warn "Created $CHILD but failed to bring it UP"
    return 0
}

# Resolve a 6GHz primary channel to the nearest allowed primary.
# hostapd's acs_usable_bw40_chan() accepts channels where (ch-1) % 4 == 0
# (ch 1,5,9,13,17,21,25,29,33,37,41,...).  PSC channels (5,21,37,53,69,...)
# satisfy (ch-1) % 16 == 4 and are a subset of these — so they are all valid.
# Any channel that does NOT satisfy (ch-1) % 4 == 0 is substituted down to
# the nearest valid primary: sub = ch - ((ch-1) % 4).  (CR-3161197)
# Prints the (possibly substituted) channel; log messages go to stderr.
resolve_6g_chan() {
    _rch_sap="$1"
    _rch_ch="$2"
    _rch_rem=$(( (_rch_ch - 1) % 4 ))
    if [ "$_rch_rem" -eq 0 ]; then
        echo "$_rch_ch"
        return 0
    fi
    _rch_sub=$(( _rch_ch - _rch_rem ))
    echo "[WARN] $_rch_sap: ch${_rch_ch} is not a valid 6GHz primary (must satisfy (ch-1)%%4==0) — substituting -> ch${_rch_sub}" >&2
    echo "[INFO] $_rch_sap: effective 6G channel = ch${_rch_sub} (requested ch${_rch_ch})" >&2
    echo "$_rch_sub"
}

# Compute 80 MHz VHT/HE center channel index for a given 5 GHz primary channel
calc_vht_seg0() {
    ch="$1"
    if   [ "$ch" -ge 36  ] && [ "$ch" -le 48  ]; then echo 42
    elif [ "$ch" -ge 52  ] && [ "$ch" -le 64  ]; then echo 58
    elif [ "$ch" -ge 100 ] && [ "$ch" -le 112 ]; then echo 106
    elif [ "$ch" -ge 116 ] && [ "$ch" -le 128 ]; then echo 122
    elif [ "$ch" -ge 132 ] && [ "$ch" -le 144 ]; then echo 138
    elif [ "$ch" -ge 149 ] && [ "$ch" -le 161 ]; then echo 155
    elif [ "$ch" -ge 165 ] && [ "$ch" -le 177 ]; then echo 171
    else echo "$ch"
    fi
}

# Compute 160 MHz VHT/HE center channel index for a given primary channel.
# For 5 GHz: standard 160 MHz channel groups.
# For 6 GHz: block_start = ch - ((ch-1) % 32); center = block_start + 14.
#   ch=1..29 → 15,  ch=33..61 → 47,  ch=65..93 → 79, etc.
calc_vht_seg0_160() {
    ch="$1"
    band="${2:-5g}"   # 5g or 6g
    if [ "$band" = "6g" ]; then
        _block=$(( ch - (ch - 1) % 32 ))
        echo $(( _block + 14 ))
    elif [ "$ch" -ge 36  ] && [ "$ch" -le 64  ]; then echo 50
    elif [ "$ch" -ge 100 ] && [ "$ch" -le 128 ]; then echo 114
    elif [ "$ch" -ge 149 ] && [ "$ch" -le 177 ]; then echo 163
    else echo "$ch"
    fi
}

# validate_5g_160_primary <sap_name> <channel>
# Checks that the requested channel is a valid 160MHz primary (not the center
# freq index itself).  If invalid, prints a WARN and returns the nearest valid
# primary in the same 160MHz block.  Echoes the final channel to use.
validate_5g_160_primary() {
    _v_sap="$1"
    _v_ch="$2"
    # Compute the center (seg0) for this channel
    _v_seg0=$(calc_vht_seg0_160 "$_v_ch" 5g)
    # If the requested channel IS the center freq index → reject
    if [ "$_v_ch" -eq "$_v_seg0" ] 2>/dev/null; then
        # Find nearest valid primary (channel before center, i.e. center-2)
        _v_nearest=$(( _v_seg0 - 2 ))
        warn "${_v_sap}: ch${_v_ch} is the 160MHz center-freq index (seg0=${_v_seg0}), not a valid primary"
        warn "${_v_sap}: substituting ch${_v_ch} -> ch${_v_nearest} (nearest valid primary in same 160MHz block)"
        echo "$_v_nearest"
        return
    fi
    # Channel is valid — return as-is
    echo "$_v_ch"
}

# Return [HT40+] or [HT40-] for a given primary channel and band.
# 5 GHz: slot = (ch-36)/4; odd slot → HT40-, even slot → HT40+
#   Covers all standard 5GHz channels: 36,40,44,48,52,56,60,64,
#   100..144, 149,153,157,161
# 6 GHz: slot = (ch-1)/4; odd slot → HT40-, even slot → HT40+
#   Covers all standard 6GHz channels: 1,5,9,13,...,233
calc_ht40_capab() {
    _ch="$1"
    _band="$2"   # 5g or 6g
    case "$_band" in
      5g) _slot=$(( (_ch - 36) / 4 )) ;;
      6g) _slot=$(( (_ch -  1) / 4 )) ;;
      *)  echo "[HT40+]"; return ;;
    esac
    if [ $(( _slot % 2 )) -eq 1 ]; then
        echo "[HT40-]"
    else
        echo "[HT40+]"
    fi
}


# Build chan_switch arguments for an already-running hostapd instance.
# Usage: calc_chan_switch_params <band> <channel> <chip_type>
# Prints: "<freq> sec_channel_offset=<1|-1> center_freq1=<MHz> bandwidth=<BW> <flags>"
# Returns 1 on unsupported input.
calc_chan_switch_params() {
    _cs_band="$1"      # 2g|5g|6g
    _cs_ch="$2"        # primary channel number
    _cs_chip="$3"      # HSP|HMT|ROME|GENOA

    case "$_cs_band" in
      2g)
        _cs_bw=40
        _cs_freq=$(( 2407 + _cs_ch * 5 ))
        if [ "$_cs_ch" -le 7 ]; then
            _cs_sec=1
            _cs_center=$(( _cs_freq + 10 ))
        else
            _cs_sec=-1
            _cs_center=$(( _cs_freq - 10 ))
        fi
        case "$_cs_chip" in
          HSP|HMT) _cs_flags="ht he" ;;
          ROME|GENOA) _cs_flags="ht" ;;
          *) _cs_flags="ht" ;;
        esac
        ;;
      5g)
        _cs_bw=80
        _cs_freq=$(( 5000 + _cs_ch * 5 ))
        # 80MHz block center (MHz) for each primary channel group
        _cs_center=""
        if   [ "$_cs_ch" -ge 36  ] && [ "$_cs_ch" -le 48  ]; then _cs_center=5210
        elif [ "$_cs_ch" -ge 52  ] && [ "$_cs_ch" -le 64  ]; then _cs_center=5290
        elif [ "$_cs_ch" -ge 100 ] && [ "$_cs_ch" -le 112 ]; then _cs_center=5530
        elif [ "$_cs_ch" -ge 116 ] && [ "$_cs_ch" -le 128 ]; then _cs_center=5610
        elif [ "$_cs_ch" -ge 132 ] && [ "$_cs_ch" -le 144 ]; then _cs_center=5690
        elif [ "$_cs_ch" -ge 149 ] && [ "$_cs_ch" -le 161 ]; then _cs_center=5775
        fi
        if [ -z "$_cs_center" ]; then
            err "calc_chan_switch_params: channel $_cs_ch is not a valid 5G primary channel"
            return 1
        fi
        # HT40+ primary channels: lower half of each 80MHz block
        case "$_cs_ch" in
          36|44|52|60|100|108|116|124|132|140|149|157) _cs_sec=1 ;;
          *) _cs_sec=-1 ;;
        esac
        case "$_cs_chip" in
          HSP|HMT)   _cs_flags="ht vht he" ;;
          ROME|GENOA) _cs_flags="ht vht" ;;
          *) _cs_flags="ht vht" ;;
        esac
        ;;
      6g)
        _cs_bw=160
        _cs_freq=$(( 5950 + _cs_ch * 5 ))
        # 160MHz block center (MHz): block_start = ch - ((ch-1)%32); center_ch = block_start+14
        _cs_block=$(( _cs_ch - (_cs_ch - 1) % 32 ))
        _cs_ctr_ch=$(( _cs_block + 14 ))
        _cs_center=$(( 5950 + _cs_ctr_ch * 5 ))
        _cs_sec=1
        # 6G: he + eht (eht listed in comment only; add when HMT eht confirmed)
        # ROME/GENOA cannot reach 6G (blocked upstream), but guard anyway
        case "$_cs_chip" in
          HSP)   _cs_flags="he" ;;    # 11ax only
          HMT)   _cs_flags="he" ;;    # eht support to be added later
          *) _cs_flags="he" ;;
        esac
        ;;
      *)
        err "calc_chan_switch_params: unsupported band '$_cs_band'"
        return 1
        ;;
    esac

    printf '%s sec_channel_offset=%s center_freq1=%s bandwidth=%s %s\n' \
        "$_cs_freq" "$_cs_sec" "$_cs_center" "$_cs_bw" "$_cs_flags"
}

# Validate band+chip compatibility and error out early.
# GENOA and ROME are 11ac only: support 2G and 5G (max 80MHz), no 6G.
# HSP and HMT are 11ax: support 2G, 5G (80MHz), and 6G (160MHz).
chip_supports_band() {
    _sap="$1"
    _band="$2"   # 2g|5g|6g
    case "$WLAN_CHIP_TYPE" in
      GENOA|ROME)
        if [ "$_band" = "6g" ]; then
            err "$_sap: 6G is not supported on $WLAN_CHIP_TYPE chip (max capability: 11ac 5G 80MHz)"
            return 1
        fi
        ;;
    esac
    return 0
}

# Validate 802.11be (Wi-Fi 7 / EHT) chip support.
# Only HMT (qca6797) supports 11be. All other chips reject it with chip capability info.
chip_supports_11be() {
    _sap="$1"
    _11be_mode="$2"  # SLO or MLO
    case "$WLAN_CHIP_TYPE" in
      HMT)
        return 0
        ;;
      HSP)
        err "$_sap: 802.11be (-${_sap}_11be $_11be_mode) is not supported on $WLAN_CHIP_TYPE chip (qca6490)"
        err "$_sap: HSP supports up to 802.11ax (Wi-Fi 6) — max BW: 2G=40MHz, 5G=160MHz, 6G=160MHz"
        return 1
        ;;
      ROME)
        err "$_sap: 802.11be (-${_sap}_11be $_11be_mode) is not supported on $WLAN_CHIP_TYPE chip (qca6574)"
        err "$_sap: ROME supports up to 802.11ac (Wi-Fi 5) — max BW: 2G=40MHz, 5G=80MHz (no 6G)"
        return 1
        ;;
      GENOA)
        err "$_sap: 802.11be (-${_sap}_11be $_11be_mode) is not supported on $WLAN_CHIP_TYPE chip (qca6595)"
        err "$_sap: GENOA supports up to 802.11ac (Wi-Fi 5) — max BW: 2G=40MHz, 5G=80MHz (no 6G)"
        return 1
        ;;
      *)
        err "$_sap: unknown chip type '$WLAN_CHIP_TYPE' — cannot validate 11be support"
        return 1
        ;;
    esac
}

# True if a band string is an MLO combo (contains '_'), e.g. "5g_2g"
is_mlo_band() {
    case "$1" in *_*) return 0 ;; *) return 1 ;; esac
}

# Split "<bandA>_<bandB>" into _MLO_BAND1 (lower freq) / _MLO_BAND2 (higher freq),
# order-agnostic (accepts "5g_2g" or "2g_5g" etc). Only the three supported
# combos are allowed: 2g+5g, 5g+6g, 2g+6g.
parse_mlo_bands() {
    _pmb_a=$(echo "$1" | cut -d_ -f1)
    _pmb_b=$(echo "$1" | cut -d_ -f2)
    case "${_pmb_a}_${_pmb_b}" in
      2g_5g|5g_2g) _MLO_BAND1="2g"; _MLO_BAND2="5g" ;;
      5g_6g|6g_5g) _MLO_BAND1="5g"; _MLO_BAND2="6g" ;;
      2g_6g|6g_2g) _MLO_BAND1="2g"; _MLO_BAND2="6g" ;;
      *) err "invalid MLO band combo '$1' (expected one of 2g_5g, 5g_6g, 2g_6g, in either order)"; return 1 ;;
    esac
    return 0
}


# ============================================================
# calc_seg0_for_bw <band> <channel> <bw_mhz>
# Returns the correct center-channel index (seg0) for any BW
# (20/40/80/160/320 MHz) across 2g/5g/6g.
# Prints empty string for 20MHz (no seg0 needed).
# ============================================================
calc_seg0_for_bw() {
    _sb_band="$1"   # 2g|5g|6g
    _sb_ch="$2"     # primary channel number
    _sb_bw="$3"     # 20|40|80|160|320
    case "$_sb_bw" in
      20)
        echo ""
        return 0
        ;;
      40)
        case "$_sb_band" in
          2g)
            if [ "$_sb_ch" -le 7 ] 2>/dev/null; then
                echo $(( _sb_ch + 2 ))
            else
                echo $(( _sb_ch - 2 ))
            fi
            ;;
          5g)
            _s40=$(( (_sb_ch - 36) / 4 ))
            if [ $(( _s40 % 2 )) -eq 0 ] 2>/dev/null; then
                echo $(( _sb_ch + 2 ))
            else
                echo $(( _sb_ch - 2 ))
            fi
            ;;
          6g)
            _s40=$(( (_sb_ch - 1) / 4 ))
            if [ $(( _s40 % 2 )) -eq 0 ] 2>/dev/null; then
                echo $(( _sb_ch + 2 ))
            else
                echo $(( _sb_ch - 2 ))
            fi
            ;;
        esac
        ;;
      80)
        case "$_sb_band" in
          5g) calc_vht_seg0 "$_sb_ch" ;;
          6g)
            _block80=$(( _sb_ch - (_sb_ch - 1) % 16 ))
            echo $(( _block80 + 6 ))
            ;;
          *) echo ""; return 1 ;;
        esac
        ;;
      160)
        case "$_sb_band" in
          5g) calc_vht_seg0_160 "$_sb_ch" 5g ;;
          6g) calc_vht_seg0_160 "$_sb_ch" 6g ;;
          *) echo ""; return 1 ;;
        esac
        ;;
      320)
        if [ "$_sb_band" != "6g" ]; then
            err "calc_seg0_for_bw: 320MHz is only supported on 6G band"
            echo ""; return 1
        fi
        # 320MHz block: block_start = ch - ((ch-1)%64); center = block_start + 30
        _block320=$(( _sb_ch - (_sb_ch - 1) % 64 ))
        echo $(( _block320 + 30 ))
        ;;
      *)
        err "calc_seg0_for_bw: unsupported BW '$_sb_bw'"
        echo ""; return 1
        ;;
    esac
}

# ============================================================
# resolve_bw_params <band> <bw_mhz> <chip_type> <11be_mode>
# Validates requested BW against chip/band limits, clamps if
# necessary, then sets output variables consumed by
# write_hostapd_conf and sap_start:
#
#   _RBW_VHT_CHWIDTH   vht_oper_chwidth value (5g only)
#   _RBW_HE_CHWIDTH    he_oper_chwidth  value (5g/6g)
#   _RBW_EHT_CHWIDTH   eht_oper_chwidth value (all bands)
#   _RBW_OP_CLASS      op_class         value (6g only)
#   _RBW_NEED_SEG0     1 if seg0 idx must be written, else 0
#   _RBW_BW            final (possibly clamped) BW in MHz
#
# vht_oper_chwidth : 0=20/40  1=80   2=160  3=80+80
# he_oper_chwidth  : 0=20/40  1=80   2=160  3=80+80
# eht_oper_chwidth : 0=20     1=40   2=80   3=160   4=320
# 6g op_class      : 131=20  132=40  133=80  134=160  137=320
# ============================================================
resolve_bw_params() {
    _rp_band="$1"     # 2g|5g|6g
    _rp_bw="$2"       # 20|40|80|160|320
    _rp_chip="$3"     # HSP|HMT|ROME|GENOA
    _rp_11be="$4"     # ""|SLO|MLO

    # Reset output variables
    _RBW_VHT_CHWIDTH=""; _RBW_HE_CHWIDTH=""; _RBW_EHT_CHWIDTH=""
    _RBW_OP_CLASS=""; _RBW_NEED_SEG0=0; _RBW_BW="$_rp_bw"

    # ── Chip max BW caps per band ───────────────────────────────────────────
    _rp_max=40   # 2G always capped at 40MHz
    case "$_rp_band" in
      5g)
        case "$_rp_chip" in
          HMT|HSP)        _rp_max=160 ;;
          ROME|GENOA)     _rp_max=80  ;;
          *)              _rp_max=80  ;;
        esac
        ;;
      6g)
        case "$_rp_chip" in
          HMT)
            if [ -n "$_rp_11be" ]; then _rp_max=320
            else _rp_max=160; fi
            ;;
          HSP)  _rp_max=160 ;;
          *)    _rp_max=0   ;;   # ROME/GENOA: no 6G support
        esac
        ;;
    esac

    # ── Clamp requested BW to chip max ─────────────────────────────────────
    if [ "$_rp_bw" -gt "$_rp_max" ] 2>/dev/null; then
        warn "resolve_bw_params: ${_rp_chip} ${_rp_band} max BW=${_rp_max}MHz — clamping ${_rp_bw}MHz -> ${_rp_max}MHz"
        _RBW_BW="$_rp_max"
    else
        _RBW_BW="$_rp_bw"
    fi

    # ── 320MHz guard: requires HMT + 6G + 11be ─────────────────────────────
    if [ "$_RBW_BW" -eq 320 ] 2>/dev/null; then
        if [ "$_rp_chip" != "HMT" ] || [ "$_rp_band" != "6g" ] || [ -z "$_rp_11be" ]; then
            err "resolve_bw_params: 320MHz requires HMT chip + 6G band + 11be (SLO or MLO)"
            return 1
        fi
    fi

    # ── Map BW -> chwidth field values ──────────────────────────────────────
    case "$_rp_band" in
      2g)
        # 2G: HT only — actual width is driven by ht_capab ([HT40+/-] or [HT20])
        # eht_oper_chwidth must always be 0 for 2G (no seg0 needed in 2G)
        case "$_RBW_BW" in
          20) _RBW_EHT_CHWIDTH=0; _RBW_NEED_SEG0=0 ;;
          40) _RBW_EHT_CHWIDTH=0; _RBW_NEED_SEG0=0 ;;
        esac
        ;;
      5g)
        case "$_RBW_BW" in
          20)  _RBW_VHT_CHWIDTH=0; _RBW_HE_CHWIDTH=0; _RBW_EHT_CHWIDTH=0; _RBW_NEED_SEG0=0 ;;
          40)  _RBW_VHT_CHWIDTH=0; _RBW_HE_CHWIDTH=0; _RBW_EHT_CHWIDTH=1; _RBW_NEED_SEG0=1 ;;
          80)  _RBW_VHT_CHWIDTH=1; _RBW_HE_CHWIDTH=1; _RBW_EHT_CHWIDTH=2; _RBW_NEED_SEG0=1 ;;
          160) _RBW_VHT_CHWIDTH=2; _RBW_HE_CHWIDTH=2; _RBW_EHT_CHWIDTH=3; _RBW_NEED_SEG0=1 ;;
        esac
        ;;
      6g)
        case "$_RBW_BW" in
          20)  _RBW_OP_CLASS=131; _RBW_HE_CHWIDTH=0; _RBW_EHT_CHWIDTH=0; _RBW_NEED_SEG0=0 ;;
          40)  _RBW_OP_CLASS=132; _RBW_HE_CHWIDTH=0; _RBW_EHT_CHWIDTH=1; _RBW_NEED_SEG0=1 ;;
          80)  _RBW_OP_CLASS=133; _RBW_HE_CHWIDTH=1; _RBW_EHT_CHWIDTH=2; _RBW_NEED_SEG0=1 ;;
          160) _RBW_OP_CLASS=134; _RBW_HE_CHWIDTH=2; _RBW_EHT_CHWIDTH=3; _RBW_NEED_SEG0=1 ;;
          320) _RBW_OP_CLASS=137; _RBW_HE_CHWIDTH=2; _RBW_EHT_CHWIDTH=4; _RBW_NEED_SEG0=1 ;;
        esac
        ;;
    esac

    return 0
}

# Write a complete hostapd config (band block + security block) to a file.
# Usage: write_hostapd_conf <band> <conf_path> <iface> <ssid> <country> <use_acs> \
#                            <channel> <ht_capab> <seg0> <security> <password> <11be_mode> [bw_mhz]
# <11be_mode> is ""|SLO|MLO — when non-empty, ieee80211be=1/beacon_prot=1 (and
# mld_ap=1 for MLO) are injected into the band block.
# <bw_mhz>  optional 13th arg — when supplied, all chwidth/op_class fields are
#           driven dynamically from _RBW_* vars set by resolve_bw_params().
#           When omitted, legacy hardcoded values are preserved for compatibility.
write_hostapd_conf() {
    _wc_band="$1"; _wc_conf="$2"; _wc_if="$3"; _wc_ssid="$4"; _wc_country="$5"
    _wc_acs="$6"; _wc_ch="$7"; _wc_htcapab="$8"; _wc_seg0="$9"
    shift 9
    _wc_sec="$1"; _wc_pass="$2"; _wc_11be="$3"; _wc_bw="${4:-}"
    # Reset any stale _RBW_* vars from a previous call so legacy fallback
    # (when _wc_bw is empty) does not accidentally pick up old values.
    if [ -z "$_wc_bw" ]; then
        _RBW_VHT_CHWIDTH=""; _RBW_HE_CHWIDTH=""; _RBW_EHT_CHWIDTH=""
        _RBW_OP_CLASS="";    _RBW_NEED_SEG0=0;  _RBW_BW=""
    fi
    case "$_wc_band" in
      2g)
        {
          printf 'ctrl_interface=/var/run\n'
          printf 'driver=nl80211\n'
          printf 'ssid=%s\n' "$_wc_ssid"
          printf 'country_code=%s\n' "$_wc_country"
          if [ "$_wc_acs" -eq 1 ]; then
              printf 'channel=0\n'
              printf 'acs_exclude_dfs=1\n'
              printf 'freqlist=\n'
          else
              printf 'channel=%s\n' "$_wc_ch"
          fi
          # Without this, hostapd scans before starting which causes the AP to
          # come up at 20MHz (scan-width) rather than the requested BW.
          printf 'ieee80211n=1\n'
          case "$WLAN_CHIP_TYPE" in
            HSP|HMT)
              printf 'ieee80211ac=1\n'
              printf 'ieee80211ax=1\n'
              # ieee80211be must come right after ieee80211ax
              [ -n "$_wc_11be" ] && printf 'ieee80211be=1\n'
              [ -n "$_wc_11be" ] && [ "$_wc_11be" = "MLO" ] && printf 'mld_ap=1\n'
              [ -n "$_wc_11be" ] && printf 'beacon_prot=1\n'
              printf 'he_su_beamformer=1\n'
              printf 'he_su_beamformee=1\n'
              printf 'he_mu_beamformer=1\n'
              # TWT not supported in 11be (SLO or MLO)
              if [ -n "$_wc_11be" ]; then
                  printf 'he_twt_required=0\n'
              else
                  printf 'he_twt_required=1\n'
              fi
              ;;
            GENOA|ROME)
              printf 'ieee80211ac=1\n'
              ;;
          esac
          printf '\n'
          printf 'hw_mode=g\n'
          printf 'ht_capab=%s\n' "$_wc_htcapab"
          # 2G: eht_oper_chwidth always 0 (width driven by ht_capab)
          if [ -n "$_wc_11be" ]; then
              printf 'eht_oper_chwidth=0\n'
          fi
          printf '\n'
          printf 'ignore_broadcast_ssid=0\n'
          printf 'wowlan_triggers=any\n'
          printf 'interworking=1\n'
          printf 'access_network_type=2\n'
          printf '\n'
          printf 'interface=%s\n' "$_wc_if"
        } > "$_wc_conf"
        ;;
      5g)
        {
          printf 'ctrl_interface=/var/run\n'
          printf 'driver=nl80211\n'
          printf 'ssid=%s\n' "$_wc_ssid"
          printf 'country_code=%s\n' "$_wc_country"
          printf '\n'
          if [ "$_wc_acs" -eq 1 ]; then
              printf 'channel=0\n'
              printf 'acs_exclude_dfs=1\n'
              printf 'freqlist=5160-5885\n'
          else
              printf 'channel=%s\n' "$_wc_ch"
          fi
          # Without this, hostapd scans for 2.4/5GHz neighbours before starting,
          # and the AP comes up at 20MHz rather than the requested BW (40/80/160).
          printf 'ieee80211n=1\n'
          case "$WLAN_CHIP_TYPE" in
            HSP|HMT)
              printf 'ieee80211ac=1\n'
              printf 'ieee80211ax=1\n'
              # ieee80211be must come right after ieee80211ax
              [ -n "$_wc_11be" ] && printf 'ieee80211be=1\n'
              [ -n "$_wc_11be" ] && [ "$_wc_11be" = "MLO" ] && printf 'mld_ap=1\n'
              [ -n "$_wc_11be" ] && printf 'beacon_prot=1\n'
              printf 'he_su_beamformer=1\n'
              printf 'he_su_beamformee=1\n'
              printf 'he_mu_beamformer=1\n'
              # TWT not supported in 11be (SLO or MLO)
              if [ -n "$_wc_11be" ]; then
                  printf 'he_twt_required=0\n'
              else
                  printf 'he_twt_required=1\n'
              fi
              ;;
            GENOA|ROME)
              printf 'ieee80211ac=1\n'
              ;;
          esac
          printf '\n'
          if [ "$_wc_acs" -eq 1 ]; then
              printf 'hw_mode=any\n'
          else
              printf 'hw_mode=a\n'
          fi
          if [ -n "$_wc_htcapab" ]; then printf 'ht_capab=%s\n' "$_wc_htcapab"; fi
           # Dynamic VHT/HE/EHT chwidth (5G)
           if [ -n "$_wc_bw" ]; then
               case "$WLAN_CHIP_TYPE" in
                 HSP|HMT)
                    if [ "$_wc_11be" = "SLO" ]; then
                        # 11be SLO: op_class + he/eht only (no vht params)
                        case "$_RBW_BW" in
                          20|40) printf 'op_class=115\n' ;;
                          80)    printf 'op_class=128\n' ;;
                          160)   printf 'op_class=129\n' ;;
                        esac
                        [ -n "$_RBW_HE_CHWIDTH" ]  && printf 'he_oper_chwidth=%s\n'  "$_RBW_HE_CHWIDTH"
                        if [ "${_RBW_HE_CHWIDTH:-0}" -gt 0 ] && [ -n "$_wc_seg0" ]; then
                            printf 'he_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
                        fi
                        [ -n "$_RBW_EHT_CHWIDTH" ] && printf 'eht_oper_chwidth=%s\n' "$_RBW_EHT_CHWIDTH"
                        if [ "${_RBW_EHT_CHWIDTH:-0}" -ge 1 ] && [ -n "$_wc_seg0" ]; then
                            printf 'eht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
                        fi
                    elif [ "$_wc_11be" = "MLO" ]; then
                        # 11be MLO: same params as SLO — mld_ap=1 already written above
                        case "$_RBW_BW" in
                          20|40) printf 'op_class=115\n' ;;
                          80)    printf 'op_class=128\n' ;;
                          160)   printf 'op_class=129\n' ;;
                        esac
                        [ -n "$_RBW_HE_CHWIDTH" ]  && printf 'he_oper_chwidth=%s\n'  "$_RBW_HE_CHWIDTH"
                        if [ "${_RBW_HE_CHWIDTH:-0}" -gt 0 ] && [ -n "$_wc_seg0" ]; then
                            printf 'he_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
                        fi
                        [ -n "$_RBW_EHT_CHWIDTH" ] && printf 'eht_oper_chwidth=%s\n' "$_RBW_EHT_CHWIDTH"
                        if [ "${_RBW_EHT_CHWIDTH:-0}" -ge 1 ] && [ -n "$_wc_seg0" ]; then
                            printf 'eht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
                        fi
                    else
                       # 11ax only: use vht_oper_chwidth + he_oper_chwidth
                       printf 'vht_oper_chwidth=%s\n' "$_RBW_VHT_CHWIDTH"
                       if [ "$_RBW_VHT_CHWIDTH" -gt 0 ] && [ -n "$_wc_seg0" ]; then
                           printf 'vht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
                       fi
                       [ -n "$_RBW_HE_CHWIDTH" ] && printf 'he_oper_chwidth=%s\n' "$_RBW_HE_CHWIDTH"
                       if [ "${_RBW_HE_CHWIDTH:-0}" -gt 0 ] && [ -n "$_wc_seg0" ]; then
                           printf 'he_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
                       fi
                   fi
                   ;;
                 GENOA|ROME)
                   printf 'vht_oper_chwidth=%s\n' "$_RBW_VHT_CHWIDTH"
                   if [ "$_RBW_VHT_CHWIDTH" -gt 0 ] && [ -n "$_wc_seg0" ]; then
                       printf 'vht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
                   fi
                   ;;
               esac
           else
               # Legacy fallback: only when no BW requested
               printf 'vht_oper_chwidth=1\n'
               if [ -n "$_wc_seg0" ]; then printf 'vht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"; fi
               case "$WLAN_CHIP_TYPE" in
                 HSP|HMT)
                   printf 'he_oper_chwidth=1\n'
                   if [ -n "$_wc_seg0" ]; then printf 'he_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"; fi
                   ;;
               esac
           fi
          printf 'ignore_broadcast_ssid=0\n'
          printf 'wowlan_triggers=any\n'
          printf 'interworking=1\n'
          printf 'access_network_type=2\n'
          printf '\n'
          printf 'interface=%s\n' "$_wc_if"
        } > "$_wc_conf"
        ;;
      6g)
        # Only reached for HSP/HMT — GENOA/ROME blocked by chip_supports_band()
        {
          printf 'ctrl_interface=/var/run\n'
          printf 'driver=nl80211\n'
          printf 'ssid=%s\n' "$_wc_ssid"
          printf 'country_code=%s\n' "$_wc_country"
          printf '\n'
          if [ "$_wc_acs" -eq 1 ]; then
              printf 'channel=0\n'
              printf 'acs_exclude_dfs=1\n'
              printf 'freqlist=5955-7115\n'
          else
              printf 'channel=%s\n' "$_wc_ch"
          fi
          printf 'hw_mode=a\n'
          # Dynamic op_class for 6G
          if [ -n "$_wc_bw" ] && [ -n "$_RBW_OP_CLASS" ]; then
              printf 'op_class=%s\n' "$_RBW_OP_CLASS"
          else
              printf 'op_class=135\n'
          fi
          printf '\n'
          printf 'ieee80211n=1\n'
          printf 'ieee80211ac=1\n'
          printf 'ieee80211ax=1\n'
          # ieee80211be must come right after ieee80211ax
          [ -n "$_wc_11be" ] && printf 'ieee80211be=1\n'
          [ -n "$_wc_11be" ] && [ "$_wc_11be" = "MLO" ] && printf 'mld_ap=1\n'
          [ -n "$_wc_11be" ] && printf 'beacon_prot=1\n'
          printf '\n'
          printf 'he_6ghz_reg_pwr_type=0\n'
          printf '\n'
          if [ -n "$_wc_htcapab" ]; then printf 'ht_capab=%s\n' "$_wc_htcapab"; fi
          # Dynamic VHT/HE/EHT chwidth for 6G
          if [ -n "$_wc_bw" ] && [ -n "$_RBW_HE_CHWIDTH" ]; then
              # vht_oper_chwidth mirrors he_oper_chwidth for 6G
              printf 'vht_oper_chwidth=%s\n' "$_RBW_HE_CHWIDTH"
              if [ "$_RBW_NEED_SEG0" -eq 1 ] && [ -n "$_wc_seg0" ]; then
                  printf 'vht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
              fi
              printf 'he_oper_chwidth=%s\n' "$_RBW_HE_CHWIDTH"
              if [ "$_RBW_NEED_SEG0" -eq 1 ] && [ -n "$_wc_seg0" ]; then
                  printf 'he_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
              fi
              printf 'eht_oper_chwidth=%s\n' "$_RBW_EHT_CHWIDTH"
              if [ "$_RBW_NEED_SEG0" -eq 1 ] && [ -n "$_wc_seg0" ]; then
                  printf 'eht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"
              fi
          else
              # Legacy fallback: hardcoded 160MHz
              printf 'vht_oper_chwidth=2\n'
              if [ -n "$_wc_seg0" ]; then printf 'vht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"; fi
              printf 'he_oper_chwidth=2\n'
              if [ -n "$_wc_seg0" ]; then printf 'he_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"; fi
              printf 'eht_oper_chwidth=2\n'
              if [ -n "$_wc_seg0" ]; then printf 'eht_oper_centr_freq_seg0_idx=%s\n' "$_wc_seg0"; fi
          fi
          printf '\n'
          printf 'he_su_beamformer=1\n'
          printf 'he_su_beamformee=1\n'
          printf 'he_mu_beamformer=1\n'
          printf 'he_twt_required=0\n'
          # ieee80211be is already written right after ieee80211ax above
          # Only write eht_oper params here if not already covered by the BW block
          printf 'ignore_broadcast_ssid=0\n'
          printf 'wowlan_triggers=any\n'
          printf 'interworking=1\n'
          printf 'access_network_type=2\n'
          printf '\n'
          printf 'interface=%s\n' "$_wc_if"
        } > "$_wc_conf"
        ;;
    esac
    # Append security block
    case "$_wc_sec" in
      OPEN)
        : # no authentication lines
        ;;
      WPA2)
        cat >> "$_wc_conf" <<EOF
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=${_wc_pass}
EOF
        ;;
      WPA3)
        cat >> "$_wc_conf" <<EOF
wpa=2
rsn_pairwise=CCMP
wpa_key_mgmt=SAE SAE-EXT-KEY
ieee80211w=2
sae_require_mfp=2
sae_pwe=2
sae_password=${_wc_pass}
EOF
        ;;
      OWE)
        cat >> "$_wc_conf" <<EOF
wpa=2
wpa_key_mgmt=OWE
rsn_pairwise=CCMP
ieee80211w=2
EOF
        ;;
    esac
}

# Build and start hostapd for one SAP & band
sap_start() {
    SAP_NAME="$1"    # SAP1|SAP2|SAP3
    IFACE="$2"       # wlan1|wlan2|wlan3
    BAND="$3"        # 2g|5g|6g
    SSID_IN="$4"     # optional, may be empty
    SEC_IN="$5"      # OPEN|WPA2|WPA3|OWE (optional; default: 2g->WPA2, 5g/6g->WPA3)
    PASS_IN="$6"     # password (optional; default: 1234567890; ignored for OWE)
    CH_IN="$7"       # specific channel number (optional; empty = use ACS channel=0)
    ELEVEN_BE_IN="$8" # ""|SLO  (MLO band combos are routed to sap_start_mlo before reaching here)
    BW_IN="${9:-}"   # 20|40|80|160|320 (optional; defaults: 2G=40, 5G=160, 6G=160)
    BAND_lc=$(echo "$BAND" | tr 'A-Z' 'a-z')
    case "$BAND_lc" in 2g|5g|6g) : ;; *) err "$SAP_NAME: invalid band '$BAND'"; return 1;; esac
    # Validate chip supports the requested band
    chip_supports_band "$SAP_NAME" "$BAND_lc" || return 1
    # Validate chip supports 802.11be when requested
    if [ -n "$ELEVEN_BE_IN" ]; then
        chip_supports_11be "$SAP_NAME" "$ELEVEN_BE_IN" || return 1
    fi
    # Default security per band if not supplied
    if [ -z "$SEC_IN" ]; then
        case "$BAND_lc" in
          2g)    SEC_IN="WPA2" ;;
          5g|6g) SEC_IN="WPA3" ;;
        esac
    fi
    SEC=$(echo "$SEC_IN" | tr 'a-z' 'A-Z')
    case "$SEC" in
      OPEN|WPA2|WPA3|OWE) : ;;
      *) err "$SAP_NAME: invalid security '$SEC_IN' (use OPEN|WPA2|WPA3|OWE)"; return 1 ;;
    esac
    if [ "$SEC" = "OWE" ]; then
        PASS=""   # OWE has no passphrase — any -SAPx_password given is ignored
    else
        PASS="${PASS_IN:-1234567890}"
    fi
    # Resolve channel: explicit value or 0 (ACS)
    # NOTE: channel=77 default for 6G+11be is removed — user-supplied channel is
    # always respected; we fall back to channel=1 (a valid PSC) only when neither
    # a channel nor ACS is possible (11be requires a fixed channel).
    if [ -n "$CH_IN" ]; then
        CHANNEL="$CH_IN"
        if [ "$BAND_lc" = "6g" ]; then
            CHANNEL=$(resolve_6g_chan "$SAP_NAME" "$CHANNEL")
        fi
        USE_ACS=0
    elif [ -n "$ELEVEN_BE_IN" ] && [ "$BAND_lc" = "6g" ]; then
        # 11be on 6G requires a fixed channel; default to PSC channel 1
        CHANNEL=1
        USE_ACS=0
        warn "$SAP_NAME: no -SAP_channel given for 6G+11be — defaulting to channel=1 (PSC)"
    else
        CHANNEL=0
        USE_ACS=1
    fi
    # ── Default BW per band if not supplied ────────────────────────────────
    case "$BAND_lc" in
      2g)  BW_FINAL="${BW_IN:-40}"  ;;
      5g)  BW_FINAL="${BW_IN:-160}" ;;
      6g)  BW_FINAL="${BW_IN:-160}" ;;
    esac
    # ── Validate & resolve all _RBW_* chwidth variables ────────────────────
    # Reset _RBW_* to avoid stale values from previous calls
    _RBW_VHT_CHWIDTH=""; _RBW_HE_CHWIDTH=""; _RBW_EHT_CHWIDTH=""
    _RBW_OP_CLASS="";    _RBW_NEED_SEG0=0;  _RBW_BW=""
    resolve_bw_params "$BAND_lc" "$BW_FINAL" "$WLAN_CHIP_TYPE" "$ELEVEN_BE_IN" || return 1
    BW_FINAL="$_RBW_BW"   # may have been clamped by resolve_bw_params
    # ── Compute ht_capab and seg0 from resolved BW ─────────────────────────
    case "$BAND_lc" in
      2g)
        if [ "$BW_FINAL" -eq 20 ]; then
            BW_HT_CAPAB="[HT20]"
            BW_SEG0=""
        else
            # 40MHz
            if [ "$CHANNEL" -eq 0 ] || [ "$CHANNEL" -le 7 ]; then
                BW_HT_CAPAB="[HT40+]"
            else
                BW_HT_CAPAB="[HT40-]"
            fi
            BW_SEG0=$(calc_seg0_for_bw "$BAND_lc" "$CHANNEL" "$BW_FINAL")
        fi
        ;;
      5g)
        if [ "$BW_FINAL" -eq 20 ] 2>/dev/null; then
            BW_HT_CAPAB="[HT20]"
            BW_SEG0=""
        elif [ "$CHANNEL" -gt 0 ]; then
            # For 160MHz: validate primary channel is not the center freq index
            if [ "$BW_FINAL" -eq 160 ] 2>/dev/null; then
                CHANNEL=$(validate_5g_160_primary "$SAP_NAME" "$CHANNEL")
            fi
            # For 11be SLO/MLO: force [HT20] to suppress HT40 neighbour scan.
            # The actual BW (40/80/160MHz) is controlled by vht/he/eht_oper_chwidth
            # + seg0 — ht_capab=[HT40+/-] is NOT needed and causes the AP to get
            # stuck at 20MHz during the scan window.
            if [ -n "$ELEVEN_BE_IN" ]; then
                # 11be: use SHORT-GI flags matching the BW, plus HT40 direction for 40MHz+
                case "$BW_FINAL" in
                  20)  BW_HT_CAPAB="[SHORT-GI-20][SHORT-GI-40]" ;;
                  40)  _ht40dir=$(calc_ht40_capab "$CHANNEL" 5g)
                       BW_HT_CAPAB="[SHORT-GI-20][SHORT-GI-40]${_ht40dir}" ;;
                  80)  _ht40dir=$(calc_ht40_capab "$CHANNEL" 5g)
                       BW_HT_CAPAB="[SHORT-GI-20][SHORT-GI-40][SHORT-GI-80]${_ht40dir}" ;;
                  160) _ht40dir=$(calc_ht40_capab "$CHANNEL" 5g)
                       BW_HT_CAPAB="[SHORT-GI-20][SHORT-GI-40][SHORT-GI-80][SHORT-GI-160]${_ht40dir}" ;;
                  *)   BW_HT_CAPAB="$(calc_ht40_capab "$CHANNEL" 5g)" ;;
                esac
            else
                BW_HT_CAPAB="$(calc_ht40_capab "$CHANNEL" 5g)"
            fi
            BW_SEG0=$(calc_seg0_for_bw "$BAND_lc" "$CHANNEL" "$BW_FINAL")
        else
            BW_HT_CAPAB="[HT40+]"
            BW_SEG0=""
        fi
        ;;
      6g)
        if [ "$BW_FINAL" -eq 20 ] 2>/dev/null; then
            BW_HT_CAPAB="[HT20]"
            BW_SEG0=""
        elif [ "$CHANNEL" -gt 0 ]; then
            # For 11be SLO/MLO: force [HT20] to suppress HT40 neighbour scan.
            if [ -n "$ELEVEN_BE_IN" ]; then
                BW_HT_CAPAB="[HT20]"
            else
                BW_HT_CAPAB="$(calc_ht40_capab "$CHANNEL" 6g)"
            fi
            BW_SEG0=$(calc_seg0_for_bw "$BAND_lc" "$CHANNEL" "$BW_FINAL")
        else
            BW_HT_CAPAB="[HT40+]"
            BW_SEG0=""
        fi
        ;;
    esac
    info "$SAP_NAME: band=$BAND_lc bw=${BW_FINAL}MHz channel=${CHANNEL} (ACS=$([ $USE_ACS -eq 1 ] && echo y || echo n)) security=$SEC${ELEVEN_BE_IN:+ 11be=$ELEVEN_BE_IN}"
    # ENV overrides
    COUNTRY="${COUNTRY:-US}"
    SSID="$SSID_IN"
    [ -z "$SSID" ] && SSID="QSoftAP_${SAP_NAME}_${BAND_lc}"
    CONF="/data/hostapd_${IFACE}.conf"
    mkdir -p /data
    stop_sap "$SAP_NAME"
    info "$SAP_NAME: ensuring interface $IFACE exists"
    ensure_ap_interface "$IFACE" || { err "$SAP_NAME: failed to ensure $IFACE"; return 1; }
    info "$SAP_NAME: writing hostapd config: $CONF (band=$BAND_lc, bw=${BW_FINAL}MHz, ssid=$SSID, security=$SEC)"
    write_hostapd_conf "$BAND_lc" "$CONF" "$IFACE" "$SSID" "$COUNTRY" "$USE_ACS" "$CHANNEL" "$BW_HT_CAPAB" "$BW_SEG0" "$SEC" "$PASS" "$ELEVEN_BE_IN" "$BW_FINAL"
    # Start hostapd
    PIDFILE="/var/run/hostapd_${IFACE}.pid"
    if [ "$DEBUG" -eq 1 ]; then
        echo "+ hostapd -B -P $PIDFILE -ddddKt $CONF"
        if ! hostapd -B -P "$PIDFILE" -ddddKt "$CONF"; then
            err "$SAP_NAME: hostapd failed to start"
            return 1
        fi
    else
        echo "+ hostapd -B -P $PIDFILE $CONF"
        if ! hostapd -B -P "$PIDFILE" "$CONF" >/dev/null 2>&1; then
            err "$SAP_NAME: hostapd failed to start"
            return 1
        fi
    fi
    _sap_try=0
    while [ "$_sap_try" -lt 15 ]; do
        iface_exists "$IFACE" && iface_is_up "$IFACE" && break
        _sap_try=$((_sap_try + 1))
        sleep 1
    done
    if iface_exists "$IFACE"; then
        if iface_is_up "$IFACE"; then
            info "SUCCESS: $SAP_NAME ($IFACE) running on $BAND_lc ${BW_FINAL}MHz"
        else
            info "SUCCESS: $SAP_NAME ($IFACE) present on $BAND_lc ${BW_FINAL}MHz (iface not RUNNING yet)"
        fi
    else
        err "FAILURE: $SAP_NAME failed — $IFACE not present"
        return 1
    fi
    return 0
}

# Build and start hostapd for one SAP's 802.11be MLO pair.
# Usage: sap_start_mlo <SAP_NAME> <iface> <band1_band2> <ssid> <sec> <pass> <ch1> <ch2> [bw1] [bw2]
sap_start_mlo() {
    SAP_NAME="$1"    # SAP1|SAP2|SAP3
    IFACE="$2"       # wlan1|wlan2|wlan3
    COMBO="$3"       # e.g. 5g_2g, 5g_6g, 2g_6g (order-agnostic)
    SSID_IN="$4"
    SEC_IN="$5"
    PASS_IN="$6"
    CH1_IN="$7"      # channel for lower-frequency band (optional; empty = ACS)
    CH2_IN="$8"      # channel for higher-frequency band (optional; empty = ACS)
    BW1_IN="${9:-}"  # BW for band1 (optional; defaults: 2G=40, 5G=80, 6G=160)
    BW2_IN="${10:-}" # BW for band2 (optional; defaults: 2G=40, 5G=80, 6G=160)
    # Extract raw input band order from COMBO (before frequency-sort)
    _raw_band1=$(echo "$COMBO" | cut -d_ -f1)
    _raw_band2=$(echo "$COMBO" | cut -d_ -f2)
    parse_mlo_bands "$COMBO" || return 1
    B1="$_MLO_BAND1"   # lower-freq band (always)
    B2="$_MLO_BAND2"   # higher-freq band (always)
    chip_supports_band "$SAP_NAME (MLO link $B1)" "$B1" || return 1
    chip_supports_band "$SAP_NAME (MLO link $B2)" "$B2" || return 1
    # Validate chip supports 802.11be MLO
    chip_supports_11be "$SAP_NAME" "MLO" || return 1
    # Remap CH1/CH2 and BW1/BW2 to match sorted band order.
    # The user always passes -SAPx_channel for raw_band1 and -SAPx_channel2
    # for raw_band2 (matching the order they typed in -SAPx_band).
    # After parse_mlo_bands the bands are re-ordered by frequency, so we
    # must swap if the user typed the higher-freq band first (e.g. "5g_2g").
    if [ "$_raw_band1" = "$B1" ]; then
        # User order matches sorted order: CH1->B1, CH2->B2
        _ch_for_b1="$CH1_IN"; _ch_for_b2="$CH2_IN"
        _bw_for_b1="$BW1_IN"; _bw_for_b2="$BW2_IN"
    else
        # User order is reversed: CH1 is for B2, CH2 is for B1
        _ch_for_b1="$CH2_IN"; _ch_for_b2="$CH1_IN"
        _bw_for_b1="$BW2_IN"; _bw_for_b2="$BW1_IN"
    fi
    SEC_IN="${SEC_IN:-WPA3}"
    SEC=$(echo "$SEC_IN" | tr 'a-z' 'A-Z')
    case "$SEC" in
      OPEN|WPA2|WPA3|OWE) : ;;
      *) err "$SAP_NAME: invalid security '$SEC_IN' (use OPEN|WPA2|WPA3|OWE)"; return 1 ;;
    esac
    if [ "$SEC" = "OWE" ]; then
        PASS=""   # OWE has no passphrase — any -SAPx_password given is ignored
    else
        PASS="${PASS_IN:-1234567890}"
    fi
    SSID="$SSID_IN"
    [ -z "$SSID" ] && SSID="QSoftAP_${SAP_NAME}_MLO"
    COUNTRY="${COUNTRY:-US}"
    mkdir -p /data
    stop_sap "$SAP_NAME"
    info "$SAP_NAME: ensuring interface $IFACE exists"
    ensure_ap_interface "$IFACE" || { err "$SAP_NAME: failed to ensure $IFACE"; return 1; }
    info "$SAP_NAME: MLO bring-up — band1=$B1 band2=$B2 security=$SEC ssid=$SSID"
    _ml_slot=1
    while [ "$_ml_slot" -le 2 ]; do
        if [ "$_ml_slot" -eq 1 ]; then
            _ml_band="$B1"; _ml_ch_in="$_ch_for_b1"; _ml_bw_in="$_bw_for_b1"
        else
            _ml_band="$B2"; _ml_ch_in="$_ch_for_b2"; _ml_bw_in="$_bw_for_b2"
        fi
        # Default BW per band
        case "$_ml_band" in
          2g)  _ml_bw="${_ml_bw_in:-40}"  ;;
          5g)  _ml_bw="${_ml_bw_in:-160}" ;;
          6g)  _ml_bw="${_ml_bw_in:-160}" ;;
        esac
        if [ -n "$_ml_ch_in" ]; then
            if [ "$_ml_band" = "6g" ]; then
                _ml_ch=$(resolve_6g_chan "$SAP_NAME" "$_ml_ch_in")
            else
                _ml_ch="$_ml_ch_in"
            fi
            _ml_acs=0
        elif [ "$_ml_band" = "6g" ]; then
            # MLO 6G link requires a fixed channel; default to PSC channel 1
            _ml_ch=1; _ml_acs=0
            warn "$SAP_NAME: no channel given for MLO 6G link — defaulting to channel=1 (PSC)"
        else
            _ml_ch=0; _ml_acs=1
        fi
        # Reset _RBW_* before each resolve to avoid stale values from previous slot
        _RBW_VHT_CHWIDTH=""; _RBW_HE_CHWIDTH=""; _RBW_EHT_CHWIDTH=""
        _RBW_OP_CLASS="";    _RBW_NEED_SEG0=0;  _RBW_BW=""
        # Resolve BW params for this link
        resolve_bw_params "$_ml_band" "$_ml_bw" "$WLAN_CHIP_TYPE" "MLO" || return 1
        _ml_bw="$_RBW_BW"
        # Compute ht_capab and seg0
        case "$_ml_band" in
          2g)
            if [ "$_ml_bw" -eq 20 ]; then
                _ml_htcapab="[HT20]"; _ml_seg0=""
            else
                if [ "$_ml_ch" -eq 0 ] || [ "$_ml_ch" -le 7 ]; then _ml_htcapab="[HT40+]"
                else _ml_htcapab="[HT40-]"; fi
                _ml_seg0=$(calc_seg0_for_bw "$_ml_band" "$_ml_ch" "$_ml_bw")
            fi
            ;;
          5g)
            if [ "$_ml_bw" -eq 20 ] 2>/dev/null; then
                _ml_htcapab="[SHORT-GI-20][SHORT-GI-40]"; _ml_seg0=""
            elif [ "$_ml_ch" -gt 0 ]; then
                # For 160MHz: validate primary channel is not the center freq index
                if [ "$_ml_bw" -eq 160 ] 2>/dev/null; then
                    _ml_ch=$(validate_5g_160_primary "$SAP_NAME" "$_ml_ch")
                fi
                # MLO 5G: same ht_capab as SLO (SHORT-GI flags + HT40 direction)
                _ml_ht40dir=$(calc_ht40_capab "$_ml_ch" 5g)
                case "$_ml_bw" in
                  40)  _ml_htcapab="[SHORT-GI-20][SHORT-GI-40]${_ml_ht40dir}" ;;
                  80)  _ml_htcapab="[SHORT-GI-20][SHORT-GI-40][SHORT-GI-80]${_ml_ht40dir}" ;;
                  160) _ml_htcapab="[SHORT-GI-20][SHORT-GI-40][SHORT-GI-80][SHORT-GI-160]${_ml_ht40dir}" ;;
                  *)   _ml_htcapab="$_ml_ht40dir" ;;
                esac
                _ml_seg0=$(calc_seg0_for_bw "$_ml_band" "$_ml_ch" "$_ml_bw")
            else
                _ml_htcapab="[SHORT-GI-20][SHORT-GI-40]"; _ml_seg0=""
            fi
            ;;
          6g)
            if [ "$_ml_bw" -eq 20 ] 2>/dev/null; then
                _ml_htcapab="[HT20]"; _ml_seg0=""
            elif [ "$_ml_ch" -gt 0 ]; then
                # MLO: force [HT20] — actual BW via he/eht_oper_chwidth + op_class
                _ml_htcapab="[HT20]"
                _ml_seg0=$(calc_seg0_for_bw "$_ml_band" "$_ml_ch" "$_ml_bw")
            else
                _ml_htcapab="[HT20]"; _ml_seg0=""
            fi
            ;;
        esac
        _ml_conf="/data/hostapd_${_ml_band}_ml.conf"
        if [ "$_ml_slot" -eq 1 ]; then CONF1="$_ml_conf"; else CONF2="$_ml_conf"; fi
        info "$SAP_NAME: writing MLO hostapd config: $_ml_conf (band=$_ml_band, bw=${_ml_bw}MHz, channel=${_ml_ch})"
        write_hostapd_conf "$_ml_band" "$_ml_conf" "$IFACE" "$SSID" "$COUNTRY" "$_ml_acs" "$_ml_ch" "$_ml_htcapab" "$_ml_seg0" "$SEC" "$PASS" "MLO" "$_ml_bw"
        _ml_slot=$((_ml_slot + 1))
    done
    PIDFILE="/var/run/hostapd_${IFACE}.pid"
    # Always pass the HIGHER-frequency band config FIRST to hostapd.
    # B2 is always the higher-frequency band (sorted by parse_mlo_bands: 2g<5g<6g).
    # CONF1=lower-freq (e.g. 2g), CONF2=higher-freq (e.g. 5g).
    # Passing 2G first causes hostapd to do an HT40 neighbour scan on Link 0,
    # which blocks Link 1 (5G) from completing MLD setup within the timeout.
    # Passing the higher-freq band first avoids the HT40 scan delay on the primary link.
    _ml_conf_primary="$CONF2"   # higher-freq band (5g or 6g) — no HT40 scan
    _ml_conf_secondary="$CONF1" # lower-freq band  (2g or 5g) — HT40 scan happens on secondary
    if [ "$DEBUG" -eq 1 ]; then
        echo "+ hostapd -B -P $PIDFILE -ddddKt $_ml_conf_primary $_ml_conf_secondary"
        if ! hostapd -B -P "$PIDFILE" -ddddKt "$_ml_conf_primary" "$_ml_conf_secondary"; then
            err "$SAP_NAME: hostapd (MLO) failed to start"
            return 1
        fi
    else
        echo "+ hostapd -B -P $PIDFILE $_ml_conf_primary $_ml_conf_secondary"
        if ! hostapd -B -P "$PIDFILE" "$_ml_conf_primary" "$_ml_conf_secondary" >/dev/null 2>&1; then
            err "$SAP_NAME: hostapd (MLO) failed to start"
            return 1
        fi
    fi
    _sap_try=0
    while [ "$_sap_try" -lt 15 ]; do
        iface_exists "$IFACE" && iface_is_up "$IFACE" && break
        _sap_try=$((_sap_try + 1))
        sleep 1
    done
    if iface_exists "$IFACE"; then
        if iface_is_up "$IFACE"; then
            info "SUCCESS: $SAP_NAME ($IFACE) running MLO ($B1+$B2)"
        else
            info "SUCCESS: $SAP_NAME ($IFACE) present MLO ($B1+$B2) (iface not RUNNING yet)"
        fi
    else
        err "FAILURE: $SAP_NAME (MLO) failed — $IFACE not present"
        return 1
    fi
    return 0
}

# -------- SAP chan_switch: switch channel without full driver reload --------
# Usage: sap_chan_switch <SAP_NAME> <band> <channel> <ssid> <security> <password>
#
# Only valid when -reload_driver n AND the interface is already UP in the same band.
# Validates that SSID, security, and password match the running config; errors out
# if any differ (a full restart would be needed in that case).
sap_chan_switch() {
    _sw_sap="$1"    # SAP1|SAP2|SAP3
    _sw_band="$2"   # 2g|5g|6g
    _sw_ch="$3"     # new primary channel
    _sw_ssid="$4"   # must match running SSID (or empty = no check)
    _sw_sec="$5"    # must match running security (or empty = no check)
    _sw_pass="$6"   # must match running password (or empty = no check)

    case "$_sw_sap" in
      SAP1) _sw_if="$SAP1_IF" ;;
      SAP2) _sw_if="$SAP2_IF" ;;
      SAP3) _sw_if="$SAP3_IF" ;;
      *) err "sap_chan_switch: unknown SAP '$_sw_sap'"; return 1 ;;
    esac

    _sw_conf="/data/hostapd_${_sw_if}.conf"
    _sw_ctrl=$(grep -m1 '^ctrl_interface=' "$_sw_conf" 2>/dev/null | cut -d= -f2)
    [ -z "$_sw_ctrl" ] && _sw_ctrl="/var/run"

    # Check hostapd is actually running on this interface
    if ! hostapd_cli -i "$_sw_if" -p "$_sw_ctrl" ping 2>/dev/null | grep -q PONG; then
        err "$_sw_sap: hostapd is not running on $_sw_if (use normal bring-up, not chan_switch)"
        return 1
    fi

    # Validate that SSID / security / password match the existing config
    if [ -f "$_sw_conf" ]; then
        _run_ssid=$(grep -m1 '^ssid=' "$_sw_conf" 2>/dev/null | cut -d= -f2-)
        _run_sec_wpa=$(grep -m1 '^wpa_key_mgmt=' "$_sw_conf" 2>/dev/null | cut -d= -f2-)
        _run_sec_sae=$(grep -m1 '^wpa=' "$_sw_conf" 2>/dev/null | cut -d= -f2-)
        _run_pass_psk=$(grep -m1 '^wpa_passphrase=' "$_sw_conf" 2>/dev/null | cut -d= -f2-)
        _run_pass_sae=$(grep -m1 '^sae_password=' "$_sw_conf" 2>/dev/null | cut -d= -f2-)

        if [ -n "$_sw_ssid" ] && [ "$_sw_ssid" != "$_run_ssid" ]; then
            err "$_sw_sap: SSID mismatch (given='$_sw_ssid' running='$_run_ssid') — restart with -reload_driver y instead"
            return 1
        fi
        # Detect running security mode
        _run_sec="OPEN"
        case "$_run_sec_wpa" in
          *SAE*) _run_sec="WPA3" ;;
          *WPA-PSK*) _run_sec="WPA2" ;;
          *OWE*) _run_sec="OWE" ;;
        esac
        if [ -n "$_sw_sec" ]; then
            _sw_sec_uc=$(echo "$_sw_sec" | tr 'a-z' 'A-Z')
            if [ "$_sw_sec_uc" != "$_run_sec" ]; then
                err "$_sw_sap: security mismatch (given='$_sw_sec_uc' running='$_run_sec') — restart with -reload_driver y instead"
                return 1
            fi
        fi
        if [ -n "$_sw_pass" ]; then
            _run_pass="${_run_pass_psk:-$_run_pass_sae}"
            if [ "$_sw_pass" != "$_run_pass" ]; then
                err "$_sw_sap: password mismatch — restart with -reload_driver y instead"
                return 1
            fi
        fi
    fi

    # Allowed-primary substitution for 6G (hostapd CR-3161197)
    if [ "$_sw_band" = "6g" ]; then
        _sw_ch=$(resolve_6g_chan "$_sw_sap" "$_sw_ch")
    fi

    # Build chan_switch arguments
    _cs_args=$(calc_chan_switch_params "$_sw_band" "$_sw_ch" "$WLAN_CHIP_TYPE") || return 1

    info "$_sw_sap: switching channel to ch${_sw_ch} (band=$_sw_band) via hostapd_cli chan_switch"
    echo "+ hostapd_cli -i $_sw_if -p $_sw_ctrl chan_switch 10 $_cs_args"
    if ! hostapd_cli -i "$_sw_if" -p "$_sw_ctrl" chan_switch 10 $_cs_args; then
        err "$_sw_sap: chan_switch command failed"
        return 1
    fi

    # Wait briefly for hostapd to complete the switch
    sleep 3
    info "$_sw_sap: chan_switch complete"
    return 0
}

# High-level bring-up entry point used by the main loop.
# Forwards BW arg to sap_start / sap_start_mlo.
sap_bring_up() {
    _bu_sap="$1"    # SAP1|SAP2|SAP3
    _bu_if="$2"     # wlan1|wlan2|wlan3
    _bu_band="$3"   # 2g|5g|6g  or  <band1>_<band2> for MLO
    _bu_ssid="$4"
    _bu_sec="$5"
    _bu_pw="$6"
    _bu_ch="$7"
    _bu_11be="$8"   # ""|SLO|MLO
    _bu_ch2="$9"    # second MLO link channel (optional)
    _bu_bw="${10:-}"  # primary BW (optional)
    _bu_bw2="${11:-}" # secondary MLO BW (optional)
    # ---- 802.11be MLO routing ----
    if [ "$_bu_11be" = "MLO" ]; then
        # Warn user if they forgot -SAPx_bw2 for the second MLO band.
        # A common mistake is typing -SAPx_bw twice (second overwrites first),
        # leaving _bu_bw2 empty so the second link defaults to band default BW.
        if [ -n "$_bu_bw" ] && [ -z "$_bu_bw2" ]; then
            warn "$_bu_sap: MLO — no BW for 2nd band (-SAP${_bu_sap#SAP}_bw2 not given); using band default (2G=40,5G=80,6G=160)"
            warn "$_bu_sap: TIP: use -SAP${_bu_sap#SAP}_bw2 <20|40|80|160> to set 2nd band BW explicitly"
        fi
        sap_start_mlo "$_bu_sap" "$_bu_if" "$_bu_band" "$_bu_ssid" "$_bu_sec" "$_bu_pw" "$_bu_ch" "$_bu_ch2" "$_bu_bw" "$_bu_bw2"
        return $?
    fi
    _bu_band_lc=$(echo "$_bu_band" | tr 'A-Z' 'a-z')
    _bu_conf="/data/hostapd_${_bu_if}.conf"
    _bu_ctrl=$(grep -m1 '^ctrl_interface=' "$_bu_conf" 2>/dev/null | cut -d= -f2)
    [ -z "$_bu_ctrl" ] && _bu_ctrl="/var/run"
    # Attempt fast chan_switch only when:
    #   1) driver reload not requested  2) interface is UP
    #   3) hostapd responding           4) specific channel given
    #   5) same running band            6) 11be not being (re)requested
    #   7) BW is not changing
    if [ -z "$_bu_11be" ] && [ "$RELOAD_DRIVER" = "n" ] && \
       iface_is_up "$_bu_if" && \
       [ -n "$_bu_ch" ] && \
       hostapd_cli -i "$_bu_if" -p "$_bu_ctrl" ping 2>/dev/null | grep -q PONG; then
        _run_hw=$(grep -m1 '^hw_mode=' "$_bu_conf" 2>/dev/null | cut -d= -f2)
        _run_op=$(grep -m1 '^op_class=' "$_bu_conf" 2>/dev/null | cut -d= -f2)
        _run_band=""
        if [ -n "$_run_op" ]; then
            _run_band="6g"
        elif [ "$_run_hw" = "a" ]; then
            _run_band="5g"
        elif [ "$_run_hw" = "g" ] || [ "$_run_hw" = "b" ]; then
            _run_band="2g"
        fi
        if [ "$_run_band" = "$_bu_band_lc" ]; then
            info "$_bu_sap: interface is UP on same band ($RELOAD_DRIVER=n, ch specified) — attempting chan_switch"
            if sap_chan_switch "$_bu_sap" "$_bu_band_lc" "$_bu_ch" "$_bu_ssid" "$_bu_sec" "$_bu_pw"; then
                return 0
            fi
            info "$_bu_sap: chan_switch failed — falling back to full restart"
        else
            info "$_bu_sap: band change detected ($_run_band->$_bu_band_lc) — full restart required"
        fi
    fi
    # Full start (driver reload or new interface or band/BW change)
    sap_start "$_bu_sap" "$_bu_if" "$_bu_band" "$_bu_ssid" "$_bu_sec" "$_bu_pw" "$_bu_ch" "$_bu_11be" "$_bu_bw"
}

# -------- STA helpers --------

mask_line() {
    line="$*"
    # mask passwords in logs
    echo "$line" | sed -E 's/(sae_password|psk|--password[= ]|-p[ ]?)"[^"]*"/\1"********"/g'
}

sta_connect() {
    ROLE="$1"       # STA1|STA2
    IFACE="$2"      # wlan0|wlan4
    SSID="$3"
    PASS="$4"       # may be empty for OPEN/OWE
    SECTYPE="$5"    # OPEN|WPA2|WPA3|OWE
    TIMEOUT="${6:-10}"
    HIDDEN="${7:-0}"

    [ -z "$SSID" ] && { err "$ROLE: SSID required"; return 1; }
    case "$(echo "$SECTYPE" | tr 'a-z' 'A-Z')" in
      OPEN)  TYPE="OPEN" ;;
      WPA2|WPA2-PSK) TYPE="WPA2" ;;
      WPA3|WPA3-SAE) TYPE="WPA3" ;;
      OWE)   TYPE="OWE" ;;
      *) err "$ROLE: invalid security '$SECTYPE' (use OPEN|WPA2|WPA3|OWE)"; return 1 ;;
    esac
    if [ "$TYPE" != "OPEN" ] && [ "$TYPE" != "OWE" ] && [ -z "$PASS" ]; then
        err "$ROLE: password required for $TYPE"
        return 1
    fi

    WPA_CONF="/data/wpa_supplicant_${IFACE}.conf"
    WPA_CTRL="/var/run/wpa_supplicant"

    mkdir -p "$(dirname "$WPA_CONF")" "$WPA_CTRL" 2>/dev/null

    if [ ! -f "$WPA_CONF" ]; then
        info "$ROLE: creating $WPA_CONF"
        {
          echo "ctrl_interface=$WPA_CTRL"
          echo "update_config=1"
        } > "$WPA_CONF"
    fi

    # Ensure STA interface exists (create managed VIF if needed)
    if ! iface_exists "$IFACE"; then
        warn "$ROLE: $IFACE not found; attempting to create managed VIF from wlan0"
        ensure_managed_interface "$IFACE" || {
            err "$ROLE: could not create $IFACE (managed) — aborting this STA bring-up"
            return 1
        }
    else
        iface_up "$IFACE" || true
    fi

    # Stop any existing wpa_supplicant on this interface before (re-)starting
    PIDFILE="/var/run/wpa_supplicant_${IFACE}.pid"
    [ -d /var/run ] || mkdir -p /var/run

    stop_sta "$ROLE" "$IFACE"

    echo "+ wpa_supplicant -B -P $PIDFILE -Dnl80211 -i $IFACE -c $WPA_CONF"
    if [ "$DEBUG" -eq 1 ]; then
        if ! wpa_supplicant -B -P "$PIDFILE" -Dnl80211 -i "$IFACE" -c "$WPA_CONF"; then
            err "$ROLE: failed to start wpa_supplicant for $IFACE"
            return 1
        fi
    else
        if ! wpa_supplicant -B -P "$PIDFILE" -Dnl80211 -i "$IFACE" -c "$WPA_CONF" >/dev/null 2>&1; then
            err "$ROLE: failed to start wpa_supplicant for $IFACE"
            return 1
        fi
    fi
    sleep 1

    trace "+ wpa_cli -i $IFACE list_networks"
    wpa_cli -i "$IFACE" list_networks >/dev/null 2>&1 || true

    trace "+ wpa_cli -i $IFACE remove_network all"
    wpa_cli -i "$IFACE" remove_network all >/dev/null 2>&1 || true
    trace "+ wpa_cli -i $IFACE add_network"
    NET_ID=$(wpa_cli -i "$IFACE" add_network 2>/dev/null | tail -n1)
    case "$NET_ID" in ''|*[!0-9]*)
        err "$ROLE: failed to add network (got '$NET_ID')"
        return 1
        ;;
    esac
    info "$ROLE: using network id $NET_ID"

    # Set SSID (escape quotes)
    _SSID=$(printf "%s" "$SSID" | sed 's/\\/\\\\/g; s/"/\\"/g')
    trace "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" ssid "\"$_SSID\"")"
    wpa_cli -i "$IFACE" set_network "$NET_ID" ssid "\"$_SSID\"" >/dev/null

    if [ "$HIDDEN" -eq 1 ]; then
        trace "+ wpa_cli -i $IFACE set_network $NET_ID scan_ssid 1"
        wpa_cli -i "$IFACE" set_network "$NET_ID" scan_ssid 1 >/dev/null
    fi

    case "$TYPE" in
      OPEN)
        trace "+ wpa_cli -i $IFACE set_network $NET_ID key_mgmt NONE"
        wpa_cli -i "$IFACE" set_network "$NET_ID" key_mgmt NONE >/dev/null
        ;;
      WPA2)
        trace "+ wpa_cli -i $IFACE set_network $NET_ID key_mgmt WPA-PSK"
        wpa_cli -i "$IFACE" set_network "$NET_ID" key_mgmt WPA-PSK >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" proto RSN >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" pairwise CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" group CCMP >/dev/null
        _PASS=$(printf "%s" "$PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
        trace "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" psk "\"$_PASS\"")"
        wpa_cli -i "$IFACE" set_network "$NET_ID" psk "\"$_PASS\"" >/dev/null
        ;;
      WPA3)
        trace "+ wpa_cli -i $IFACE set_network $NET_ID key_mgmt SAE"
        wpa_cli -i "$IFACE" set_network "$NET_ID" key_mgmt SAE >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" pairwise CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" group CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" ieee80211w 2 >/dev/null
        _PASS=$(printf "%s" "$PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
        if wpa_cli -i "$IFACE" set_network "$NET_ID" sae_password "\"$_PASS\"" 2>/dev/null | grep -q "^OK"; then
            trace "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" sae_password "\"$_PASS\"")   # OK"
        else
            warn "$ROLE: sae_password unsupported; falling back to psk"
            trace "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" psk "\"$_PASS\"")"
            wpa_cli -i "$IFACE" set_network "$NET_ID" psk "\"$_PASS\"" >/dev/null
        fi
        wpa_cli -i "$IFACE" set sae_pwe 1 >/dev/null 2>&1 || true
        wpa_cli -i "$IFACE" set sae_groups "19 20 21" >/dev/null 2>&1 || true
        ;;
      OWE)
        trace "+ wpa_cli -i $IFACE set_network $NET_ID key_mgmt OWE"
        wpa_cli -i "$IFACE" set_network "$NET_ID" key_mgmt OWE >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" proto RSN >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" pairwise CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" group CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" ieee80211w 2 >/dev/null
        ;;
    esac

    wpa_cli -i "$IFACE" enable_network "$NET_ID" >/dev/null
    wpa_cli -i "$IFACE" select_network "$NET_ID" >/dev/null
    wpa_cli -i "$IFACE" save_config >/dev/null || true
    wpa_cli -i "$IFACE" scan >/dev/null || true

    info "$ROLE: waiting up to ${TIMEOUT}s for connection to \"$SSID\""
    i=0
    while [ "$i" -lt "$TIMEOUT" ]; do
        STATUS=$(wpa_cli -i "$IFACE" status 2>/dev/null || :)
        echo "$STATUS" | grep -q '^wpa_state=COMPLETED' && echo "$STATUS" | grep -q "^ssid=$SSID$" && {
            IP=$(echo "$STATUS" | awk -F= '/^ip_address=/{print $2}' | head -n1)
            [ -n "$IP" ] && info "✅ $ROLE connected: $IFACE -> $SSID (ip=$IP)" || info "✅ $ROLE connected: $IFACE -> $SSID"
            return 0
        }
        i=$((i+1))
        sleep 1
    done

    err "$ROLE: failed to connect within ${TIMEOUT}s"
    echo "---- wpa_cli status (last) ----"
    wpa_cli -i "$IFACE" status || true
    echo "---- Nearby scan results (top 10) ----"
    wpa_cli -i "$IFACE" scan_results 2>/dev/null | head -n 12 || true
    return 1
}

# -------- Stop helpers --------
# Stop hostapd instance associated with SAPx (reliable: CLI -> pidfile -> ps fallback)
stop_sap() {
    SAP_NAME="$1"   # SAP1|SAP2|SAP3
    case "$SAP_NAME" in
      SAP1) IFACE="$SAP1_IF" ;;
      SAP2) IFACE="$SAP2_IF" ;;
      SAP3) IFACE="$SAP3_IF" ;;
      *) err "stop_sap: unknown SAP '$SAP_NAME'"; return 1 ;;
    esac

    CONF="/data/hostapd_${IFACE}.conf"
    PIDFILE="/var/run/hostapd_${IFACE}.pid"
    killed=0

    # 1) Try control socket (clean exit)
    if command -v hostapd_cli >/dev/null 2>&1; then
        # If CLI responds to ping, ask it to terminate
        if hostapd_cli -i "$IFACE" ping 2>/dev/null | grep -q PONG; then
            echo "+ hostapd_cli -i $IFACE terminate"
            if hostapd_cli -i "$IFACE" terminate >/dev/null 2>&1; then
                killed=1
                # Give it a moment to exit and remove pidfile
                sleep 1
            fi
        fi
    fi

    # 2) PID file kill (fast and precise)
    if [ "$killed" -eq 0 ] && [ -f "$PIDFILE" ]; then
        PID="$(cat "$PIDFILE" 2>/dev/null | tr -d '[:space:]')"
        case "$PID" in
          ''|*[!0-9]*) PID="";;
        esac
        if [ -n "$PID" ]; then
            trace "+ kill $PID   # hostapd for $SAP_NAME ($IFACE via pidfile)"
            kill "$PID" 2>/dev/null || true
            sleep 1
            # If still alive, try SIGKILL
            if kill -0 "$PID" 2>/dev/null; then
                trace "+ kill -9 $PID"
                kill -9 "$PID" 2>/dev/null || true
            fi
            killed=1
        fi
        # Clean up stale pidfile
        [ -f "$PIDFILE" ] && rm -f "$PIDFILE" 2>/dev/null || true
    fi

    # 3) ps-based fallback (try to match on iface or conf path)
    if [ "$killed" -eq 0 ]; then
        if ps -ef >/dev/null 2>&1; then
            PIDS="$(ps -ef | grep '[h]ostapd' | grep -E "$CONF|$IFACE" | awk '{print $2}')"
        else
            # BusyBox 'ps w' fallback
            PIDS="$(ps w 2>/dev/null | grep '[h]ostapd' | grep -E "$CONF|$IFACE" | awk '{print $1}')"
        fi
        for pid in $PIDS; do
            trace "+ kill $pid   # hostapd for $SAP_NAME (matched by $IFACE|$CONF)"
            kill "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                trace "+ kill -9 $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
            killed=1
        done
    fi

    if [ "$killed" -eq 0 ]; then
        info "$SAP_NAME: no hostapd process found for iface=$IFACE (CONF=$CONF, PIDFILE=$PIDFILE)"
    else
        info "$SAP_NAME: stop requested"
        # Only bring interface down when we actually killed a running hostapd.
        # Skipping when killed=0 prevents tearing down a freshly-created VIF
        # that sap_start() just raised via ensure_ap_interface().
        if iface_exists "$IFACE"; then
            iface_down "$IFACE" && info "$SAP_NAME: $IFACE brought down" || warn "$SAP_NAME: failed to bring $IFACE down"
        fi
    fi
}

# Stop wpa_supplicant for a specific STA iface (-i wlanX) — robust:
# 1) wpa_cli terminate (clean) -> 2) pidfile kill -> 3) ps fallback
stop_sta() {
    ROLE="$1"   # STA1|STA2
    IFACE="$2"
    killed=0
    PIDFILE="/var/run/wpa_supplicant_${IFACE}.pid"

    # 1) Try control socket first (clean shutdown)
    if command -v wpa_cli >/dev/null 2>&1; then
        if wpa_cli -i "$IFACE" ping 2>/dev/null | grep -q PONG; then
            trace "+ wpa_cli -i $IFACE terminate"
            if wpa_cli -i "$IFACE" terminate >/dev/null 2>&1; then
                killed=1
                sleep 1
            fi
        fi
    fi

    # 2) PID file: precise and fast
    if [ "$killed" -eq 0 ] && [ -f "$PIDFILE" ]; then
        PID="$(cat "$PIDFILE" 2>/dev/null | tr -d '[:space:]')"
        case "$PID" in ''|*[!0-9]*) PID="";; esac
        if [ -n "$PID" ]; then
            trace "+ kill $PID   # wpa_supplicant for $ROLE ($IFACE via pidfile)"
            kill "$PID" 2>/dev/null || true
            sleep 1
            if kill -0 "$PID" 2>/dev/null; then
                trace "+ kill -9 $PID"
                kill -9 "$PID" 2>/dev/null || true
            fi
            killed=1
        fi
        # Clean stale pidfile
        [ -f "$PIDFILE" ] && rm -f "$PIDFILE" 2>/dev/null || true
    fi

    # 3) ps-based fallback — handle both "-i IFACE" and "-iIFACE" forms
    if [ "$killed" -eq 0 ]; then
        if ps -ef >/dev/null 2>&1; then
            # Match either ' -i IFACE ' or ' -iIFACE' patterns
            PIDS="$(ps -ef | grep '[w]pa_supplicant' | grep -E " -i ?$IFACE( |$)" | awk '{print $2}')"
        else
            PIDS="$(ps w 2>/dev/null | grep '[w]pa_supplicant' | grep -E " -i ?$IFACE( |$)" | awk '{print $1}')"
        fi
        for pid in $PIDS; do
            trace "+ kill $pid   # wpa_supplicant for $ROLE ($IFACE matched by ps)"
            kill "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                trace "+ kill -9 $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
            killed=1
        done
    fi

    if [ "$killed" -eq 0 ]; then
        info "$ROLE: no wpa_supplicant process found for $IFACE"
    else
        info "$ROLE: stop requested"
        if iface_exists "$IFACE"; then
            iface_down "$IFACE" && info "$ROLE: $IFACE brought down" || warn "$ROLE: failed to bring $IFACE down"
        fi
    fi
}

# -------- CLI parsing --------

usage() {
cat <<'EOF'
Usage (examples):

# Unload WLAN driver only (auto-detects chip via lsmod, kills hostapd/wpa_supplicant):
  sh ./wlan_sap_sta_setup.sh -unload_driver y

# Only SAP1:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1 \
     -SAP1_band <2g|5g|6g> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3|OWE>] [-SAP1_password <pwd>] \
     [-SAP1_channel <ch>]

# SAP1 with 802.11be Single-Link Operation (SLO) — single band, EHT params added:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1 \
     -SAP1_band <2g|5g|6g> -SAP1_security <OPEN|WPA2|WPA3|OWE> -SAP1_11be SLO

# SAP1 with 802.11be Multi-Link Operation (MLO) — two-band combo, two hostapd
# configs sharing one interface, launched via a single hostapd process:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1 \
     -SAP1_band <5g_2g|5g_6g|2g_6g> -SAP1_security <OPEN|WPA2|WPA3|OWE> -SAP1_11be MLO \
     [-SAP1_channel <ch_for_input_band1>] [-SAP1_channel2 <ch_for_input_band2>] \
     [-SAP1_bw <20|40|80|160>]         [-SAP1_bw2 <20|40|80|160>]
#                                           ^^^^ USE -SAP1_bw2 for second MLO band BW
#                                                (NOT -SAP1_bw a second time!)
# NOTE: -SAP1_channel/-SAP1_bw always correspond to the FIRST band as typed in
#       -SAP1_band (left side), and -SAP1_channel2/-SAP1_bw2 to the SECOND band
#       (right side). e.g. -SAP1_band 5g_2g: channel=5G_ch, channel2=2G_ch

# SAP1 + SAP2:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3|OWE>] [-SAP1_password <pwd>] [-SAP1_channel <ch>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] [-SAP2_security <OPEN|WPA2|WPA3|OWE>] [-SAP2_password <pwd>] [-SAP2_channel <ch>]

# SAP1 + SAP2 + SAP3 + STA1:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2,SAP3 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3|OWE>] [-SAP1_password <pwd>] [-SAP1_channel <ch>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] [-SAP2_security <OPEN|WPA2|WPA3|OWE>] [-SAP2_password <pwd>] [-SAP2_channel <ch>] \
     -SAP3_band <band> [-SAP3_ssid <ssid>] [-SAP3_security <OPEN|WPA2|WPA3|OWE>] [-SAP3_password <pwd>] [-SAP3_channel <ch>] \
     -STA_interfaces STA1 -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN|OWE>

# STA1 only:
  sh ./wlan_sap_sta_setup.sh -reload_driver n -STA_interfaces STA1 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN|OWE> [-STA1_timeout <sec>]

# STA1 + STA2:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -STA_interfaces STA1,STA2 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN|OWE> [-STA1_timeout <sec>] \
     -STA2_ssid <ssid> -STA2_password <pwd> -STA2_security <WPA2|WPA3|OPEN|OWE> [-STA2_timeout <sec>]

# Mix SAP and STA:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2,SAP3 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3|OWE>] [-SAP1_password <pwd>] [-SAP1_channel <ch>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] [-SAP2_security <OPEN|WPA2|WPA3|OWE>] [-SAP2_password <pwd>] [-SAP2_channel <ch>] \
     -SAP3_band <band> [-SAP3_ssid <ssid>] [-SAP3_security <OPEN|WPA2|WPA3|OWE>] [-SAP3_password <pwd>] [-SAP3_channel <ch>] \
     -STA_interfaces STA1,STA2 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN|OWE> \
     -STA2_ssid <ssid> -STA2_password <pwd> -STA2_security <WPA2|WPA3|OPEN|OWE>

# Stop selected interfaces (no driver reload):
  sh ./wlan_sap_sta_setup.sh -stop SAP1,STA2

# Control bring-up order (default: all SAPs first, then all STAs):
  sh ./wlan_sap_sta_setup.sh -reload_driver y \
     -SAP_interfaces SAP1,SAP2 -SAP1_band 5g -SAP2_band 2g \
     -STA_interfaces STA1 -STA1_ssid MyNet -STA1_security WPA2 -STA1_password mypass \
     -bring_up_order STA1,SAP1,SAP2
  # This brings up STA1 first, then SAP1, then SAP2 (instead of default SAP1,SAP2,STA1)

# Enable debug output (command traces + daemon verbose logs):
  sh ./wlan_sap_sta_setup.sh -d -reload_driver y -SAP_interfaces SAP1 -SAP1_band 5g

SAP security defaults (when -SAPx_security is omitted):
  2G -> WPA2   5G -> WPA3   6G -> WPA3
  Default password (when -SAPx_password is omitted): 1234567890
  OWE (Opportunistic Wireless Encryption) is opt-in only via -SAPx_security OWE;
  it has no passphrase — -SAPx_password is ignored when security=OWE.

STA connection timeout defaults (when -STAx_timeout is omitted):
  30s  (WPA3-SAE on 5GHz HE can take 15-20s on embedded; 30s gives safe margin)

Notes:
- Config paths are per-interface:
    hostapd:        /data/hostapd_<iface>.conf
    wpa_supplicant: /data/wpa_supplicant_<iface>.conf
  802.11be MLO uses two band-keyed configs instead (see below).
- Bring-up order (optional, default: all SAPs first, then all STAs):
    -bring_up_order <comma-separated-list>
    Example: -bring_up_order STA1,SAP1,SAP2 brings up STA1 first, then SAP1, then SAP2
    Must only reference interfaces listed in -SAP_interfaces and -STA_interfaces
    If omitted, defaults to: all SAPs in order, then all STAs in order
- Channel per SAP (optional):
    -SAPx_channel <ch>  : fixed channel (disables ACS); omit for ACS (channel=0)
    Bandwidth (optional, default per band: 2G=40MHz, 5G=80MHz, 6G=160MHz):
    -SAPx_bw <20|40|80|160|320>   primary band BW (auto-clamped to chip max)
    -SAPx_bw2 <20|40|80|160|320>  MLO second band BW (ignored for SLO/legacy)
    Chip BW caps: ROME/GENOA=2G:40/5G:80  HSP=2G:40/5G:160/6G:160  HMT=2G:40/5G:160/6G:160(320 with 11be)
    320MHz: HMT + 6G + 11be (SLO or MLO) only
- Fast channel switch (no driver reload):
    When -reload_driver n AND the SAP is already UP in the same band AND a channel is
    given AND -SAPx_11be is not set, the script uses hostapd_cli chan_switch instead of a
    full restart. SSID, security, and password must match the running config — any
    mismatch returns an error (use -reload_driver y to change those parameters).
- 802.11be (Wi-Fi 7 / EHT) — SLO and MLO (-SAPx_11be SLO|MLO):
    SLO: -SAPx_band is a single band (2g|5g|6g). Adds ieee80211be=1 (+ eht_oper_chwidth
      and beacon_prot=1) to that band's existing /data/hostapd_<iface>.conf — same
      hostapd start command as today, just with the added EHT lines.
    MLO: -SAPx_band is a two-band combo, order-agnostic: 5g_2g (or 2g_5g), 5g_6g
      (or 6g_5g), 2g_6g (or 6g_2g). Writes two separate configs, one per band —
      /data/hostapd_<band>_ml.conf — both containing ieee80211be=1 and mld_ap=1
      (plus beacon_prot=1 and the per-band EHT width/seg0 params), sharing the same
      SSID/security/interface. Both configs are passed to a single hostapd process:
        hostapd -B -P /var/run/hostapd_<iface>.pid [-ddddKt] <conf_band1> <conf_band2>
      Use -SAPx_channel / -SAPx_channel2 to fix the channel for the first/second band
      respectively (order matches how the bands were split from -SAPx_band); omit
      either for ACS on that link. Only one SAP should run MLO at a time, since the
      MLO config filenames are band-keyed (not interface-keyed).
    6G+11be (SLO or MLO): -SAPx_channel / -SAPx_channel2 are honoured for the 6G link.
      If no channel is given, defaults to PSC channel=1. The channel is always passed
      through resolve_6g_chan() to ensure it satisfies hostapd CR-3161197.
- Debug mode (-d flag):
    Without -d: only [INFO]/[WARN]/[ERROR] messages are shown; daemon output
      (hostapd, wpa_supplicant, wpa_cli) is suppressed.
    With -d: all command traces (+ ...) and full daemon stdout/stderr are printed.
- Environment overrides for SAP:
    COUNTRY=US
EOF
}

# Defaults
RELOAD_DRIVER="n"
UNLOAD_DRIVER="n"
SAP_LIST=""
STA_LIST=""
STOP_LIST=""
BRING_UP_ORDER=""  # empty = default (SAPs first, then STAs); user can override with comma-separated list

# Per-interface params
SAP1_BAND=""; SAP1_SSID=""; SAP1_SEC=""; SAP1_PW=""; SAP1_CH=""; SAP1_11BE=""; SAP1_CH2=""; SAP1_BW=""; SAP1_BW2=""
SAP2_BAND=""; SAP2_SSID=""; SAP2_SEC=""; SAP2_PW=""; SAP2_CH=""; SAP2_11BE=""; SAP2_CH2=""; SAP2_BW=""; SAP2_BW2=""
SAP3_BAND=""; SAP3_SSID=""; SAP3_SEC=""; SAP3_PW=""; SAP3_CH=""; SAP3_11BE=""; SAP3_CH2=""; SAP3_BW=""; SAP3_BW2=""

STA1_SSID=""; STA1_PW=""; STA1_SEC=""; STA1_TIMEOUT=30
STA2_SSID=""; STA2_PW=""; STA2_SEC=""; STA2_TIMEOUT=30

# Parse
while [ "$#" -gt 0 ]; do
  case "$1" in
    -reload_driver) RELOAD_DRIVER="$2"; shift 2;;
    -unload_driver) UNLOAD_DRIVER="$2"; shift 2;;
    -SAP_interfaces) SAP_LIST="$2"; shift 2;;
    -STA_interfaces) STA_LIST="$2"; shift 2;;

    -SAP1_band)     SAP1_BAND="$2"; shift 2;;
    -SAP1_ssid)     SAP1_SSID="$2"; shift 2;;
    -SAP1_security) SAP1_SEC="$2";  shift 2;;
    -SAP1_password) SAP1_PW="$2";   shift 2;;
    -SAP1_channel)  SAP1_CH="$2";   shift 2;;
    -SAP1_channel2) SAP1_CH2="$2";  shift 2;;
    -SAP1_bw)       SAP1_BW="$2";   shift 2;;
    -SAP1_bw2)      SAP1_BW2="$2";  shift 2;;
    # Guard: user may accidentally type -SAP1_bw twice; detect and warn
    # The second -SAP1_bw simply overwrites SAP1_BW (last-write-wins) which
    # silently ignores the intended BW for the second MLO band. The correct
    # flag is -SAP1_bw2. We cannot fully prevent this in POSIX sh arg parsing,
    # but we emit a clear warning at bring-up time if SAP1_BW2 is empty during MLO.
    -SAP1_11be)     SAP1_11BE="$2"; shift 2;;
    -SAP2_band)     SAP2_BAND="$2"; shift 2;;
    -SAP2_ssid)     SAP2_SSID="$2"; shift 2;;
    -SAP2_security) SAP2_SEC="$2";  shift 2;;
    -SAP2_password) SAP2_PW="$2";   shift 2;;
    -SAP2_channel)  SAP2_CH="$2";   shift 2;;
    -SAP2_channel2) SAP2_CH2="$2";  shift 2;;
    -SAP2_bw)       SAP2_BW="$2";   shift 2;;
    -SAP2_bw2)      SAP2_BW2="$2";  shift 2;;
    -SAP2_11be)     SAP2_11BE="$2"; shift 2;;
    -SAP3_band)     SAP3_BAND="$2"; shift 2;;
    -SAP3_ssid)     SAP3_SSID="$2"; shift 2;;
    -SAP3_security) SAP3_SEC="$2";  shift 2;;
    -SAP3_password) SAP3_PW="$2";   shift 2;;
    -SAP3_channel)  SAP3_CH="$2";   shift 2;;
    -SAP3_channel2) SAP3_CH2="$2";  shift 2;;
    -SAP3_bw)       SAP3_BW="$2";   shift 2;;
    -SAP3_bw2)      SAP3_BW2="$2";  shift 2;;
    -SAP3_11be)     SAP3_11BE="$2"; shift 2;;

    -STA1_ssid)      STA1_SSID="$2";    shift 2;;
    -STA1_password)  STA1_PW="$2";      shift 2;;
    -STA1_security)  STA1_SEC="$2";     shift 2;;
    -STA1_timeout)   STA1_TIMEOUT="$2"; shift 2;;
    -STA2_ssid)      STA2_SSID="$2";    shift 2;;
    -STA2_password)  STA2_PW="$2";      shift 2;;
    -STA2_security)  STA2_SEC="$2";     shift 2;;
    -STA2_timeout)   STA2_TIMEOUT="$2"; shift 2;;

    -stop) STOP_LIST="$2"; shift 2;;
    -bring_up_order) BRING_UP_ORDER="$2"; shift 2;;
    -d) DEBUG=1; shift;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 2;;
  esac
done

# Validate reload_driver and unload_driver
case "$RELOAD_DRIVER" in y|n) : ;; *) err "-reload_driver must be y or n"; exit 2;; esac
case "$UNLOAD_DRIVER" in y|n) : ;; *) err "-unload_driver must be y or n"; exit 2;; esac

# Validate -SAPx_11be (SLO|MLO) against the corresponding SAPx_band
for _v_sap in SAP1 SAP2 SAP3; do
    eval "_v_11be=\"\$${_v_sap}_11BE\""
    eval "_v_band=\"\$${_v_sap}_BAND\""
    [ -z "$_v_11be" ] && continue
    case "$_v_11be" in
      SLO|MLO) : ;;
      *) err "-${_v_sap}_11be must be SLO or MLO (got '$_v_11be')"; exit 2 ;;
    esac
    if [ "$_v_11be" = "MLO" ] && ! is_mlo_band "$_v_band"; then
        err "$_v_sap: -${_v_sap}_11be MLO requires a two-band combo for -${_v_sap}_band (e.g. 5g_2g, 5g_6g, 2g_6g), got '$_v_band'"
        exit 2
    fi
    if [ "$_v_11be" = "SLO" ] && is_mlo_band "$_v_band"; then
        err "$_v_sap: -${_v_sap}_11be SLO requires a single band for -${_v_sap}_band (2g|5g|6g), got '$_v_band'"
        exit 2
    fi
done

# -------- Step 1: Detect chip (and optionally reload) --------
if ! detect_chip; then
    # If user only requested -stop or -unload_driver, continue; else abort
    if [ -n "$STOP_LIST" ] && [ -z "$SAP_LIST$STA_LIST" ]; then
        warn "Chip detection failed but proceeding with -stop operations"
    elif [ "$UNLOAD_DRIVER" = "y" ]; then
        warn "Chip detection failed but proceeding with -unload_driver"
    else
        exit 1
    fi
fi

# Unload driver if requested (exits immediately after)
if [ "$UNLOAD_DRIVER" = "y" ]; then
    unload_driver
    exit $?
fi

# Reload driver if requested
reload_driver_if_requested "$RELOAD_DRIVER"

# -------- Step 2: Show which interfaces are UP --------
show_up_interfaces_table

# -------- Stop-only path --------
if [ -n "$STOP_LIST" ] && [ -z "$SAP_LIST$STA_LIST" ]; then
    info "Stopping requested interfaces: $STOP_LIST"
    IFS=','; for item in $STOP_LIST; do
        case "$item" in
          SAP1) stop_sap SAP1 ;;
          SAP2) stop_sap SAP2 ;;
          SAP3) stop_sap SAP3 ;;
          STA1) stop_sta STA1 "$STA1_IF" ;;
          STA2) stop_sta STA2 "$STA2_IF" ;;
          *) warn "Unknown stop target: $item" ;;
        esac
    done
    show_up_interfaces_table
    exit 0
fi

# -------- Step 3: Bring up SAPs and/or STAs in requested order --------
FAILS=0

# Determine bring-up order: use -bring_up_order if provided, else default (SAPs first, then STAs)
if [ -z "$BRING_UP_ORDER" ]; then
    # Default: all SAPs first, then all STAs
    _ORDER=""
    if [ -n "$SAP_LIST" ]; then
        IFS=','; for sap in $SAP_LIST; do
            _ORDER="${_ORDER}${_ORDER:+,}$sap"
        done
    fi
    if [ -n "$STA_LIST" ]; then
        IFS=','; for sta in $STA_LIST; do
            _ORDER="${_ORDER}${_ORDER:+,}$sta"
        done
    fi
    BRING_UP_ORDER="$_ORDER"
fi

# Validate that all items in BRING_UP_ORDER are in SAP_LIST or STA_LIST
IFS=','; for item in $BRING_UP_ORDER; do
    _found=0
    if [ -n "$SAP_LIST" ]; then
        IFS=','; for sap in $SAP_LIST; do
            [ "$item" = "$sap" ] && { _found=1; break; }
        done
    fi
    if [ "$_found" -eq 0 ] && [ -n "$STA_LIST" ]; then
        IFS=','; for sta in $STA_LIST; do
            [ "$item" = "$sta" ] && { _found=1; break; }
        done
    fi
    if [ "$_found" -eq 0 ]; then
        err "-bring_up_order: '$item' is not in -SAP_interfaces or -STA_interfaces"
        exit 2
    fi
done

# Bring up interfaces in the specified order
IFS=','; for item in $BRING_UP_ORDER; do
    case "$item" in
      SAP1)
        if [ -z "$SAP1_BAND" ]; then warn "SAP1 requested but -SAP1_band missing"; FAILS=$((FAILS+1)); else
            sap_bring_up "SAP1" "$SAP1_IF" "$SAP1_BAND" "$SAP1_SSID" "$SAP1_SEC" "$SAP1_PW" "$SAP1_CH" "$SAP1_11BE" "$SAP1_CH2" "$SAP1_BW" "$SAP1_BW2" || FAILS=$((FAILS+1))
        fi
      ;;
      SAP2)
        if [ -z "$SAP2_BAND" ]; then warn "SAP2 requested but -SAP2_band missing"; FAILS=$((FAILS+1)); else
            sap_bring_up "SAP2" "$SAP2_IF" "$SAP2_BAND" "$SAP2_SSID" "$SAP2_SEC" "$SAP2_PW" "$SAP2_CH" "$SAP2_11BE" "$SAP2_CH2" "$SAP2_BW" "$SAP2_BW2" || FAILS=$((FAILS+1))
        fi
      ;;
      SAP3)
        if [ -z "$SAP3_BAND" ]; then warn "SAP3 requested but -SAP3_band missing"; FAILS=$((FAILS+1)); else
            sap_bring_up "SAP3" "$SAP3_IF" "$SAP3_BAND" "$SAP3_SSID" "$SAP3_SEC" "$SAP3_PW" "$SAP3_CH" "$SAP3_11BE" "$SAP3_CH2" "$SAP3_BW" "$SAP3_BW2" || FAILS=$((FAILS+1))
        fi
      ;;
      STA1)
        if [ -z "$STA1_SSID" ] || [ -z "$STA1_SEC" ]; then
            warn "STA1 requires -STA1_ssid and -STA1_security"; FAILS=$((FAILS+1))
        else
            sta_connect "STA1" "$STA1_IF" "$STA1_SSID" "$STA1_PW" "$STA1_SEC" "$STA1_TIMEOUT" 0 || FAILS=$((FAILS+1))
        fi
      ;;
      STA2)
        if [ -z "$STA2_SSID" ] || [ -z "$STA2_SEC" ]; then
            warn "STA2 requires -STA2_ssid and -STA2_security"; FAILS=$((FAILS+1))
        else
            sta_connect "STA2" "$STA2_IF" "$STA2_SSID" "$STA2_PW" "$STA2_SEC" "$STA2_TIMEOUT" 0 || FAILS=$((FAILS+1))
        fi
      ;;
      *) warn "Unknown interface in -bring_up_order: $item"; FAILS=$((FAILS+1)) ;;
    esac
done

# -------- Step 4: Show which interfaces are UP --------
show_up_interfaces_table wait

# Final status
if [ "$FAILS" -gt 0 ]; then
    warn "Completed with $FAILS failure(s). See logs above for details."
    exit 1
else
    info "All requested interfaces started successfully."
    exit 0
fi
