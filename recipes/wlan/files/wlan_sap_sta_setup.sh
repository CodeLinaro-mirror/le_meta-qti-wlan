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
#
# Mappings (hardcoded):
#   STA1=wlan0, STA2=wlan4
#   SAP1=wlan1, SAP2=wlan2, SAP3=wlan3
#
# Chip modules:
#   HSP=qca6490  (11ax: 2G 40MHz, 5G 80MHz, 6G 160MHz)
#   HMT=qca6797  (11ax: 2G 40MHz, 5G 80MHz, 6G 160MHz)
#   ROME=qca6574 (11ac: 2G 40MHz, 5G 80MHz — no 6G)
#   GENOA=qca6595(11ac: 2G 40MHz, 5G 80MHz — no 6G)
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

# Resolve a 6GHz primary channel to the nearest allowed primary in the same
# 160MHz block.  hostapd's acs_usable_bw40_chan() only accepts channels where
# (ch-1) % 8 == 0 (ch1,9,17,25,33,41,49,...).  Any other channel is rejected,
# not just PSC.  Substitute = ch - ((ch-1) % 8), which is the floor of ch
# rounded down to the nearest multiple-of-8 boundary (CR-3161197).
# Prints the (possibly substituted) channel; log messages go to stderr so
# they are visible on the terminal but not captured by $(...) callers.
resolve_6g_chan() {
    _rch_sap="$1"
    _rch_ch="$2"
    _rch_rem=$(( (_rch_ch - 1) % 8 ))
    if [ "$_rch_rem" -eq 0 ]; then
        echo "$_rch_ch"
        return 0
    fi
    _rch_sub=$(( _rch_ch - _rch_rem ))
    echo "[WARN] $_rch_sap: ch${_rch_ch} is not an allowed 6GHz primary — hostapd CR-3161197 (acs_usable_bw40_chan) rejects it" >&2
    echo "[WARN] $_rch_sap: substituting ch${_rch_ch} -> ch${_rch_sub} (nearest allowed primary in same 160MHz block)" >&2
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

# Build and start hostapd for one SAP & band
sap_start() {
    SAP_NAME="$1"    # SAP1|SAP2|SAP3
    IFACE="$2"       # wlan1|wlan2|wlan3
    BAND="$3"        # 2g|5g|6g
    SSID_IN="$4"     # optional, may be empty
    SEC_IN="$5"      # OPEN|WPA2|WPA3 (optional; default: 2g->WPA2, 5g/6g->WPA3)
    PASS_IN="$6"     # password (optional; default: 1234567890)
    CH_IN="$7"       # specific channel number (optional; empty = use ACS channel=0)
    BAND_lc=$(echo "$BAND" | tr 'A-Z' 'a-z')
    case "$BAND_lc" in 2g|5g|6g) : ;; *) err "$SAP_NAME: invalid band '$BAND'"; return 1;; esac

    # Validate chip supports the requested band
    chip_supports_band "$SAP_NAME" "$BAND_lc" || return 1

    # Default security per band if not supplied
    if [ -z "$SEC_IN" ]; then
        case "$BAND_lc" in
          2g)    SEC_IN="WPA2" ;;
          5g|6g) SEC_IN="WPA3" ;;
        esac
    fi
    SEC=$(echo "$SEC_IN" | tr 'a-z' 'A-Z')
    case "$SEC" in
      OPEN|WPA2|WPA3) : ;;
      *) err "$SAP_NAME: invalid security '$SEC_IN' (use OPEN|WPA2|WPA3)"; return 1 ;;
    esac

    PASS="${PASS_IN:-1234567890}"

    # Resolve channel: explicit value or 0 (ACS)
    if [ -n "$CH_IN" ]; then
        CHANNEL="$CH_IN"
        # Allowed-primary substitution for 6G fixed channels (hostapd CR-3161197)
        if [ "$BAND_lc" = "6g" ]; then
            CHANNEL=$(resolve_6g_chan "$SAP_NAME" "$CHANNEL")
        fi
        USE_ACS=0
    else
        CHANNEL=0
        USE_ACS=1
    fi

    # Fixed bandwidth per band: 2G=40MHz, 5G=80MHz, 6G=160MHz
    case "$BAND_lc" in
      2g)
        if [ "$CHANNEL" -eq 0 ] || [ "$CHANNEL" -le 7 ]; then
            BW_HT_CAPAB="[HT40+]"
        else
            BW_HT_CAPAB="[HT40-]"
        fi
        ;;
      5g)
        if [ "$CHANNEL" -gt 0 ]; then
            BW_HT_CAPAB="$(calc_ht40_capab "$CHANNEL" 5g)"
            BW_SEG0="$(calc_vht_seg0 "$CHANNEL")"
        else
            BW_HT_CAPAB="[HT40+]"
            BW_SEG0=""
        fi
        ;;
      6g)
        if [ "$CHANNEL" -gt 0 ]; then
            BW_HT_CAPAB="$(calc_ht40_capab "$CHANNEL" 6g)"
            BW_SEG0="$(calc_vht_seg0_160 "$CHANNEL" 6g)"
        else
            BW_HT_CAPAB="[HT40+]"
            BW_SEG0=""
        fi
        ;;
    esac

    info "$SAP_NAME: band=$BAND_lc channel=${CHANNEL} (ACS=$([ $USE_ACS -eq 1 ] && echo y || echo n)) security=$SEC"

    # ENV overrides (SAP-level env vars for country / fallback channels)
    COUNTRY="${COUNTRY:-US}"

    SSID="$SSID_IN"
    [ -z "$SSID" ] && SSID="QSoftAP_${SAP_NAME}_${BAND_lc}"
    CONF="/data/hostapd_${IFACE}.conf"

    mkdir -p /data

    # Stop any existing hostapd on this interface first (before creating/raising VIF),
    # so iface_down inside stop_sap only fires when something was actually running.
    stop_sap "$SAP_NAME"

    info "$SAP_NAME: ensuring interface $IFACE exists"
    ensure_ap_interface "$IFACE" || { err "$SAP_NAME: failed to ensure $IFACE"; return 1; }

    info "$SAP_NAME: writing hostapd config: $CONF (band=$BAND_lc, ssid=$SSID, security=$SEC)"

    # Write band-specific base config
    # Channel/ACS logic:
    #   USE_ACS=1 → channel=0 + ACS params
    #   USE_ACS=0 → channel=<CHANNEL>, no ACS params
    case "$BAND_lc" in
      2g)
        {
          printf 'ctrl_interface=/var/run\n'
          printf 'driver=nl80211\n'
          printf 'ssid=%s\n' "$SSID"
          printf 'country_code=%s\n' "$COUNTRY"
          if [ "$USE_ACS" -eq 1 ]; then
              printf 'channel=0\n'
              printf 'acs_exclude_dfs=1\n'
              printf 'freqlist=\n'
          else
              printf 'channel=%s\n' "$CHANNEL"
          fi
          printf 'ieee80211n=1\n'
          case "$WLAN_CHIP_TYPE" in
            HSP|HMT)
              printf 'ieee80211ac=1\n'
              printf 'ieee80211ax=1\n'
              printf 'he_su_beamformer=1\n'
              printf 'he_su_beamformee=1\n'
              printf 'he_mu_beamformer=1\n'
              printf 'he_twt_required=1\n'
              ;;
            GENOA|ROME)
              printf 'ieee80211ac=1\n'
              ;;
          esac
          printf '\n'
          printf 'hw_mode=g\n'
          printf 'ht_capab=%s\n' "$BW_HT_CAPAB"
          printf '\n'
          printf 'ignore_broadcast_ssid=0\n'
          printf 'wowlan_triggers=any\n'
          printf 'interworking=1\n'
          printf 'access_network_type=2\n'
          printf '\n'
          printf 'interface=%s\n' "$IFACE"
        } > "$CONF"
        ;;
      5g)
        {
          printf 'ctrl_interface=/var/run\n'
          printf 'driver=nl80211\n'
          printf 'ssid=%s\n' "$SSID"
          printf 'country_code=%s\n' "$COUNTRY"
          printf '\n'
          if [ "$USE_ACS" -eq 1 ]; then
              printf 'channel=0\n'
              printf 'acs_exclude_dfs=1\n'
              printf 'freqlist=5160-5885\n'
          else
              printf 'channel=%s\n' "$CHANNEL"
          fi
          printf 'ieee80211n=1\n'
          case "$WLAN_CHIP_TYPE" in
            HSP|HMT)
              printf 'ieee80211ac=1\n'
              printf 'ieee80211ax=1\n'
              printf 'he_su_beamformer=1\n'
              printf 'he_su_beamformee=1\n'
              printf 'he_mu_beamformer=1\n'
              printf 'he_twt_required=1\n'
              ;;
            GENOA|ROME)
              printf 'ieee80211ac=1\n'
              ;;
          esac
          printf '\n'
          if [ "$USE_ACS" -eq 1 ]; then
              printf 'hw_mode=any\n'
          else
              printf 'hw_mode=a\n'
          fi
          if [ -n "$BW_HT_CAPAB" ]; then printf 'ht_capab=%s\n' "$BW_HT_CAPAB"; fi
          printf 'vht_oper_chwidth=1\n'
          if [ -n "$BW_SEG0" ]; then printf 'vht_oper_centr_freq_seg0_idx=%s\n' "$BW_SEG0"; fi
          case "$WLAN_CHIP_TYPE" in
            HSP|HMT)
              printf 'he_oper_chwidth=1\n'
              ;;
          esac
          printf 'ignore_broadcast_ssid=0\n'
          printf 'wowlan_triggers=any\n'
          printf 'interworking=1\n'
          printf 'access_network_type=2\n'
          printf '\n'
          printf 'interface=%s\n' "$IFACE"
        } > "$CONF"
        ;;
      6g)
        # Only reached for HSP/HMT — GENOA/ROME blocked by chip_supports_band()
        {
          printf 'ctrl_interface=/var/run\n'
          printf 'driver=nl80211\n'
          printf 'ssid=%s\n' "$SSID"
          printf 'country_code=%s\n' "$COUNTRY"
          printf '\n'
          if [ "$USE_ACS" -eq 1 ]; then
              printf 'channel=0\n'
              printf 'acs_exclude_dfs=1\n'
              printf 'freqlist=5955-7115\n'
          else
              printf 'channel=%s\n' "$CHANNEL"
          fi
          printf 'hw_mode=a\n'
          printf 'op_class=135\n'
          printf '\n'
          printf 'ieee80211n=1\n'
          printf 'ieee80211ac=1\n'
          printf 'ieee80211ax=1\n'
          printf '\n'
          printf 'he_6ghz_reg_pwr_type=0\n'
          printf '\n'
          printf 'ht_capab=[HT40+]\n'
          printf 'vht_oper_chwidth=2\n'
          if [ -n "$BW_SEG0" ]; then printf 'vht_oper_centr_freq_seg0_idx=%s\n' "$BW_SEG0"; fi
          printf 'he_oper_chwidth=2\n'
          if [ -n "$BW_SEG0" ]; then printf 'he_oper_centr_freq_seg0_idx=%s\n' "$BW_SEG0"; fi
          printf 'eht_oper_chwidth=2\n'
          if [ -n "$BW_SEG0" ]; then printf 'eht_oper_centr_freq_seg0_idx=%s\n' "$BW_SEG0"; fi
          printf '\n'
          printf 'he_su_beamformer=1\n'
          printf 'he_su_beamformee=1\n'
          printf 'he_mu_beamformer=1\n'
          printf 'he_twt_required=0\n'
          printf 'ignore_broadcast_ssid=0\n'
          printf 'wowlan_triggers=any\n'
          printf 'interworking=1\n'
          printf 'access_network_type=2\n'
          printf '\n'
          printf 'interface=%s\n' "$IFACE"
        } > "$CONF"
        ;;
    esac

    # Append security block
    case "$SEC" in
      OPEN)
        : # no authentication lines
        ;;
      WPA2)
        cat >> "$CONF" <<EOF
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=${PASS}
EOF
        ;;
      WPA3)
        cat >> "$CONF" <<EOF
wpa=2
rsn_pairwise=CCMP
wpa_key_mgmt=SAE SAE-EXT-KEY
ieee80211w=2
sae_require_mfp=2
sae_pwe=2
sae_password=${PASS}
EOF
        ;;
    esac

    # Start hostapd (write a per-interface pidfile)
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

    # Poll until the interface is RUNNING or timeout (15s).
    # VHT160 setup can take several seconds even with noscan=1.
    _sap_try=0
    while [ "$_sap_try" -lt 15 ]; do
        iface_exists "$IFACE" && iface_is_up "$IFACE" && break
        _sap_try=$((_sap_try + 1))
        sleep 1
    done

    if iface_exists "$IFACE"; then
        if iface_is_up "$IFACE"; then
            info "SUCCESS: $SAP_NAME ($IFACE) running on $BAND_lc"
        else
            info "SUCCESS: $SAP_NAME ($IFACE) present on $BAND_lc (iface not RUNNING yet)"
        fi
    else
        err "FAILURE: $SAP_NAME failed — $IFACE not present"
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
# When -reload_driver n AND the SAP interface is already UP in the same band
# AND only the channel differs → use chan_switch instead of a full restart.
# In all other cases delegates to sap_start.
sap_bring_up() {
    _bu_sap="$1"    # SAP1|SAP2|SAP3
    _bu_if="$2"     # wlan1|wlan2|wlan3
    _bu_band="$3"   # 2g|5g|6g
    _bu_ssid="$4"
    _bu_sec="$5"
    _bu_pw="$6"
    _bu_ch="$7"

    _bu_band_lc=$(echo "$_bu_band" | tr 'A-Z' 'a-z')
    _bu_conf="/data/hostapd_${_bu_if}.conf"
    _bu_ctrl=$(grep -m1 '^ctrl_interface=' "$_bu_conf" 2>/dev/null | cut -d= -f2)
    [ -z "$_bu_ctrl" ] && _bu_ctrl="/var/run"

    # Attempt fast chan_switch only when:
    #   1) driver reload was not requested
    #   2) interface is currently UP
    #   3) hostapd is responding on this interface
    #   4) a specific channel was requested (chan_switch with ACS=0 makes no sense)
    #   5) the running band (hw_mode) matches the requested band
    if [ "$RELOAD_DRIVER" = "n" ] && \
       iface_is_up "$_bu_if" && \
       [ -n "$_bu_ch" ] && \
       hostapd_cli -i "$_bu_if" -p "$_bu_ctrl" ping 2>/dev/null | grep -q PONG; then

        # Read the band currently in the running config
        _run_hw=$(grep -m1 '^hw_mode=' "$_bu_conf" 2>/dev/null | cut -d= -f2)
        _run_op=$(grep -m1 '^op_class=' "$_bu_conf" 2>/dev/null | cut -d= -f2)

        # Map hw_mode (+op_class) to band string
        _run_band=""
        if [ -n "$_run_op" ]; then
            _run_band="6g"      # op_class present only in 6G config
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
            info "$_bu_sap: band change detected ($run_band→$_bu_band_lc) — full restart required"
        fi
    fi

    # Full start (driver reload or new interface or band change)
    sap_start "$_bu_sap" "$_bu_if" "$_bu_band" "$_bu_ssid" "$_bu_sec" "$_bu_pw" "$_bu_ch"
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
    PASS="$4"       # may be empty for OPEN
    SECTYPE="$5"    # OPEN|WPA2|WPA3
    TIMEOUT="${6:-10}"
    HIDDEN="${7:-0}"

    [ -z "$SSID" ] && { err "$ROLE: SSID required"; return 1; }
    case "$(echo "$SECTYPE" | tr 'a-z' 'A-Z')" in
      OPEN)  TYPE="OPEN" ;;
      WPA2|WPA2-PSK) TYPE="WPA2" ;;
      WPA3|WPA3-SAE) TYPE="WPA3" ;;
      *) err "$ROLE: invalid security '$SECTYPE' (use OPEN|WPA2|WPA3)"; return 1 ;;
    esac
    if [ "$TYPE" != "OPEN" ] && [ -z "$PASS" ]; then
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
     -SAP1_band <2g|5g|6g> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3>] [-SAP1_password <pwd>] \
     [-SAP1_channel <ch>]

# SAP1 + SAP2:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3>] [-SAP1_password <pwd>] [-SAP1_channel <ch>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] [-SAP2_security <OPEN|WPA2|WPA3>] [-SAP2_password <pwd>] [-SAP2_channel <ch>]

# SAP1 + SAP2 + SAP3 + STA1:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2,SAP3 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3>] [-SAP1_password <pwd>] [-SAP1_channel <ch>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] [-SAP2_security <OPEN|WPA2|WPA3>] [-SAP2_password <pwd>] [-SAP2_channel <ch>] \
     -SAP3_band <band> [-SAP3_ssid <ssid>] [-SAP3_security <OPEN|WPA2|WPA3>] [-SAP3_password <pwd>] [-SAP3_channel <ch>] \
     -STA_interfaces STA1 -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN>

# STA1 only:
  sh ./wlan_sap_sta_setup.sh -reload_driver n -STA_interfaces STA1 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN> [-STA1_timeout <sec>]

# STA1 + STA2:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -STA_interfaces STA1,STA2 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN> [-STA1_timeout <sec>] \
     -STA2_ssid <ssid> -STA2_password <pwd> -STA2_security <WPA2|WPA3|OPEN> [-STA2_timeout <sec>]

# Mix SAP and STA:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2,SAP3 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] [-SAP1_security <OPEN|WPA2|WPA3>] [-SAP1_password <pwd>] [-SAP1_channel <ch>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] [-SAP2_security <OPEN|WPA2|WPA3>] [-SAP2_password <pwd>] [-SAP2_channel <ch>] \
     -SAP3_band <band> [-SAP3_ssid <ssid>] [-SAP3_security <OPEN|WPA2|WPA3>] [-SAP3_password <pwd>] [-SAP3_channel <ch>] \
     -STA_interfaces STA1,STA2 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN> \
     -STA2_ssid <ssid> -STA2_password <pwd> -STA2_security <WPA2|WPA3|OPEN>

# Stop selected interfaces (no driver reload):
  sh ./wlan_sap_sta_setup.sh -stop SAP1,STA2

# Enable debug output (command traces + daemon verbose logs):
  sh ./wlan_sap_sta_setup.sh -d -reload_driver y -SAP_interfaces SAP1 -SAP1_band 5g

SAP security defaults (when -SAPx_security is omitted):
  2G -> WPA2   5G -> WPA3   6G -> WPA3
  Default password (when -SAPx_password is omitted): 1234567890

STA connection timeout defaults (when -STAx_timeout is omitted):
  30s  (WPA3-SAE on 5GHz HE can take 15-20s on embedded; 30s gives safe margin)

Notes:
- Config paths are per-interface:
    hostapd:        /data/hostapd_<iface>.conf
    wpa_supplicant: /data/wpa_supplicant_<iface>.conf
- Channel per SAP (optional):
    -SAPx_channel <ch>  : fixed channel (disables ACS); omit for ACS (channel=0)
    Bandwidth is fixed per band: 2G=40MHz, 5G=80MHz, 6G=160MHz
- Fast channel switch (no driver reload):
    When -reload_driver n AND the SAP is already UP in the same band AND a channel is
    given, the script uses hostapd_cli chan_switch instead of a full restart.
    SSID, security, and password must match the running config — any mismatch returns
    an error (use -reload_driver y to change those parameters).
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

# Per-interface params
SAP1_BAND=""; SAP1_SSID=""; SAP1_SEC=""; SAP1_PW=""; SAP1_CH=""
SAP2_BAND=""; SAP2_SSID=""; SAP2_SEC=""; SAP2_PW=""; SAP2_CH=""
SAP3_BAND=""; SAP3_SSID=""; SAP3_SEC=""; SAP3_PW=""; SAP3_CH=""

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
    -SAP2_band)     SAP2_BAND="$2"; shift 2;;
    -SAP2_ssid)     SAP2_SSID="$2"; shift 2;;
    -SAP2_security) SAP2_SEC="$2";  shift 2;;
    -SAP2_password) SAP2_PW="$2";   shift 2;;
    -SAP2_channel)  SAP2_CH="$2";   shift 2;;
    -SAP3_band)     SAP3_BAND="$2"; shift 2;;
    -SAP3_ssid)     SAP3_SSID="$2"; shift 2;;
    -SAP3_security) SAP3_SEC="$2";  shift 2;;
    -SAP3_password) SAP3_PW="$2";   shift 2;;
    -SAP3_channel)  SAP3_CH="$2";   shift 2;;

    -STA1_ssid)      STA1_SSID="$2";    shift 2;;
    -STA1_password)  STA1_PW="$2";      shift 2;;
    -STA1_security)  STA1_SEC="$2";     shift 2;;
    -STA1_timeout)   STA1_TIMEOUT="$2"; shift 2;;
    -STA2_ssid)      STA2_SSID="$2";    shift 2;;
    -STA2_password)  STA2_PW="$2";      shift 2;;
    -STA2_security)  STA2_SEC="$2";     shift 2;;
    -STA2_timeout)   STA2_TIMEOUT="$2"; shift 2;;

    -stop) STOP_LIST="$2"; shift 2;;
    -d) DEBUG=1; shift;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 2;;
  esac
done

# Validate reload_driver and unload_driver
case "$RELOAD_DRIVER" in y|n) : ;; *) err "-reload_driver must be y or n"; exit 2;; esac
case "$UNLOAD_DRIVER" in y|n) : ;; *) err "-unload_driver must be y or n"; exit 2;; esac

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

# -------- Step 3: Bring up SAPs (then STAs) --------
FAILS=0

# Bring up SAPs
if [ -n "$SAP_LIST" ]; then
    IFS=','; for sap in $SAP_LIST; do
        case "$sap" in
          SAP1)
            if [ -z "$SAP1_BAND" ]; then warn "SAP1 requested but -SAP1_band missing"; FAILS=$((FAILS+1)); else
                sap_bring_up "SAP1" "$SAP1_IF" "$SAP1_BAND" "$SAP1_SSID" "$SAP1_SEC" "$SAP1_PW" "$SAP1_CH" || FAILS=$((FAILS+1))
            fi
          ;;
          SAP2)
            if [ -z "$SAP2_BAND" ]; then warn "SAP2 requested but -SAP2_band missing"; FAILS=$((FAILS+1)); else
                sap_bring_up "SAP2" "$SAP2_IF" "$SAP2_BAND" "$SAP2_SSID" "$SAP2_SEC" "$SAP2_PW" "$SAP2_CH" || FAILS=$((FAILS+1))
            fi
          ;;
          SAP3)
            if [ -z "$SAP3_BAND" ]; then warn "SAP3 requested but -SAP3_band missing"; FAILS=$((FAILS+1)); else
                sap_bring_up "SAP3" "$SAP3_IF" "$SAP3_BAND" "$SAP3_SSID" "$SAP3_SEC" "$SAP3_PW" "$SAP3_CH" || FAILS=$((FAILS+1))
            fi
          ;;
          *) warn "Unknown SAP interface: $sap"; FAILS=$((FAILS+1)) ;;
        esac
    done
fi

# Bring up STAs
if [ -n "$STA_LIST" ]; then
    IFS=','; for sta in $STA_LIST; do
        case "$sta" in
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
          *) warn "Unknown STA interface: $sta"; FAILS=$((FAILS+1)) ;;
        esac
    done
fi

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
