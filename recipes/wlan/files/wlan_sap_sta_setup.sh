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
#   HSP=qca6490, HMT=qca6797, ROME=qca6574, GENOA=qca6595
#
# Config files (per-interface):
#   hostapd:       /data/hostapd_<iface>.conf       (e.g., /data/hostapd_wlan1.conf)
#   wpa_supplicant:/data/wpa_supplicant_<iface>.conf (e.g., /data/wpa_supplicant_wlan0.conf)
# ============================================================

# -------- Logging --------
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err()  { echo "[ERROR] $*" >&2; }

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

# Search order for probing when unknown
CHIP_ORDER="$HSP $HMT $ROME $GENOA"

# Will be set by detection
WLAN_CHIP_TYPE=""
WLAN_MODULE_NAME=""

# -------- Simple execution helpers --------
run_print() {
    echo "+ $*"
    sh -c "$*"
    return $?
}

safe_killall() {
    # killall <proc> non-fatal if not running
    p="$1"
    echo "+ (safe) killall $p"
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
    # Try lsmod first
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

    # Try modprobe in order; first successful (exit 0) is our chip
    for mod in $CHIP_ORDER; do
        printf "+ modprobe %s\n" "$mod"
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

        # Try removing any of the known modules (ignore failure)
        for mod in $CHIP_ORDER; do
            printf "+ rmmod %s\n" "$mod"
            rmmod "$mod" >/dev/null 2>&1 || true
        done

        printf "+ modprobe %s\n" "$WLAN_MODULE_NAME"
        if ! modprobe "$WLAN_MODULE_NAME" >/dev/null 2>&1; then
            die "modprobe $WLAN_MODULE_NAME failed after detection"
        fi
        sleep 2
    else
        info "Driver reload not requested (-reload_driver n)"
    fi
}

# -------- Visibility (Step 2): show UP interfaces table --------
show_up_interfaces_table() {
    echo ""
    echo "=== Interfaces UP (role -> iface) ==="
    shown=0
    for role_if in "STA1:$STA1_IF" "STA2:$STA2_IF" "SAP1:$SAP1_IF" "SAP2:$SAP2_IF" "SAP3:$SAP3_IF"; do
        role=$(echo "$role_if" | cut -d: -f1)
        ifc=$(echo "$role_if" | cut -d: -f2)
        if iface_exists "$ifc" && iface_is_up "$ifc"; then
            echo "$role    $ifc"
            shown=1
        fi
    done
    [ "$shown" -eq 0 ] && echo "(none UP)"
    echo "======================================"
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

# Build and start hostapd for one SAP & band
sap_start() {
    SAP_NAME="$1"    # SAP1|SAP2|SAP3
    IFACE="$2"       # wlan1|wlan2|wlan3
    BAND="$3"        # 2g|5g|6g
    SSID_IN="$4"     # optional, may be empty

    BAND_lc=$(echo "$BAND" | tr 'A-Z' 'a-z')
    case "$BAND_lc" in 2g|5g|6g) : ;; *) err "$SAP_NAME: invalid band '$BAND'"; return 1;; esac

    # ENV overrides
    COUNTRY="${COUNTRY:-US}"
    CH2G="${CH2G:-6}"
    CH5G="${CH5G:-36}"
    VHT_SEG0_5G="${VHT_SEG0_5G:-50}"
    CH6G="${CH6G:-77}"

    SSID="$SSID_IN"
    [ -z "$SSID" ] && SSID="QSoftAP_${SAP_NAME}_${BAND_lc}"
    CONF="/data/hostapd_${IFACE}.conf"

    mkdir -p /data

    info "$SAP_NAME: ensuring interface $IFACE exists"
    ensure_ap_interface "$IFACE" || { err "$SAP_NAME: failed to ensure $IFACE"; return 1; }

    info "$SAP_NAME: writing hostapd config: $CONF (band=$BAND_lc, ssid=$SSID)"
    case "$BAND_lc" in
      2g)
        cat > "$CONF" <<EOF
ctrl_interface=/var/run
driver=nl80211
ssid=${SSID}
country_code=${COUNTRY}
channel=0
acs_exclude_dfs=1
freqlist=
ieee80211n=1
ieee80211ac=1
ieee80211ax=1
he_su_beamformer=1
he_su_beamformee=1
he_mu_beamformer=1
he_twt_required=1

hw_mode=g

ignore_broadcast_ssid=0
wowlan_triggers=any
interworking=1
access_network_type=2

wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=1234567890
interface=${IFACE}
EOF
      ;;
      5g)
        cat > "$CONF" <<EOF
ctrl_interface=/var/run
driver=nl80211
ssid=${SSID}
country_code=${COUNTRY}

channel=0
acs_exclude_dfs=1
freqlist=2412-2484,5160-5885
ieee80211n=1
ieee80211ac=1
ieee80211ax=1
he_su_beamformer=1
he_su_beamformee=1
he_mu_beamformer=1
he_twt_required=1

hw_mode=any
ht_capab=[HT40+]
vht_oper_chwidth=1
he_oper_chwidth=1
eht_oper_chwidth=1
ignore_broadcast_ssid=0
wowlan_triggers=any
interworking=1
access_network_type=2

wpa=2
rsn_pairwise=CCMP
wpa_key_mgmt=SAE SAE-EXT-KEY
ieee80211w=2
sae_require_mfp=2
sae_pwe=2
sae_password=1234567890
interface=${IFACE}
EOF
      ;;
      6g)
        cat > "$CONF" <<EOF
ctrl_interface=/var/run
driver=nl80211
ssid=${SSID}
country_code=${COUNTRY}

channel=0
acs_exclude_dfs=1
freqlist=
ieee80211n=1
ieee80211ac=1
ieee80211ax=1
he_su_beamformer=1
he_su_beamformee=1
he_mu_beamformer=1
he_twt_required=1


hw_mode=any
ht_capab=[HT40+]
vht_oper_chwidth=1
op_class=137
he_oper_chwidth=1
eht_oper_chwidth=1
ignore_broadcast_ssid=0
wowlan_triggers=any
interworking=1
access_network_type=2

wpa=2
rsn_pairwise=CCMP
wpa_key_mgmt=SAE SAE-EXT-KEY
ieee80211w=2
sae_require_mfp=2
sae_pwe=2
sae_password=1234567890
interface=${IFACE}
EOF
      ;;
    esac

    # Start hostapd (write a per-interface pidfile)
    PIDFILE="/var/run/hostapd_${IFACE}.pid"
    echo "+ hostapd -B -P $PIDFILE -ddddKt $CONF"
    if ! hostapd -B -P "$PIDFILE" -ddddKt "$CONF"; then
        err "$SAP_NAME: hostapd failed to start"
        return 1
    fi

    sleep 3

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

    # Start wpa_supplicant if not responsive on this iface
    PIDFILE="/var/run/wpa_supplicant_${IFACE}.pid"
    [ -d /var/run ] || mkdir -p /var/run

    if ! wpa_cli -i "$IFACE" ping 2>/dev/null | grep -q PONG; then
        echo "+ wpa_supplicant -B -P $PIDFILE -Dnl80211 -i $IFACE -c $WPA_CONF"
        if ! wpa_supplicant -B -P "$PIDFILE" -Dnl80211 -i "$IFACE" -c "$WPA_CONF"; then
            err "$ROLE: failed to start wpa_supplicant for $IFACE"
            return 1
        fi
        sleep 1
    else
        info "$ROLE: wpa_supplicant already responding on $IFACE"
    fi

    echo "+ wpa_cli -i $IFACE list_networks"
    wpa_cli -i "$IFACE" list_networks || true

    #Remove all network
    echo "+ wpa_cli -i $IFACE remove_network all"
    wpa_cli -i "$IFACE" remove_network all || true
    # Add fresh network
    echo "+ wpa_cli -i $IFACE add_network"
    NET_ID=$(wpa_cli -i "$IFACE" add_network | tail -n1)
    case "$NET_ID" in ''|*[!0-9]*)
        err "$ROLE: failed to add network (got '$NET_ID')"
        return 1
        ;;
    esac
    info "$ROLE: using network id $NET_ID"

    # Set SSID (escape quotes)
    _SSID=$(printf "%s" "$SSID" | sed 's/\\/\\\\/g; s/"/\\"/g')
    echo "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" ssid "\"$_SSID\"")"
    wpa_cli -i "$IFACE" set_network "$NET_ID" ssid "\"$_SSID\"" >/dev/null

    if [ "$HIDDEN" -eq 1 ]; then
        echo "+ wpa_cli -i $IFACE set_network $NET_ID scan_ssid 1"
        wpa_cli -i "$IFACE" set_network "$NET_ID" scan_ssid 1 >/dev/null
    fi

    case "$TYPE" in
      OPEN)
        echo "+ wpa_cli -i $IFACE set_network $NET_ID key_mgmt NONE"
        wpa_cli -i "$IFACE" set_network "$NET_ID" key_mgmt NONE >/dev/null
        ;;
      WPA2)
        echo "+ wpa_cli -i $IFACE set_network $NET_ID key_mgmt WPA-PSK"
        wpa_cli -i "$IFACE" set_network "$NET_ID" key_mgmt WPA-PSK >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" proto RSN >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" pairwise CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" group CCMP >/dev/null
        _PASS=$(printf "%s" "$PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
        echo "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" psk "\"$_PASS\"")"
        wpa_cli -i "$IFACE" set_network "$NET_ID" psk "\"$_PASS\"" >/dev/null
        ;;
      WPA3)
        echo "+ wpa_cli -i $IFACE set_network $NET_ID key_mgmt SAE"
        wpa_cli -i "$IFACE" set_network "$NET_ID" key_mgmt SAE >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" pairwise CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" group CCMP >/dev/null
        wpa_cli -i "$IFACE" set_network "$NET_ID" ieee80211w 2 >/dev/null
        _PASS=$(printf "%s" "$PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
        if wpa_cli -i "$IFACE" set_network "$NET_ID" sae_password "\"$_PASS\"" 2>/dev/null | grep -q "^OK"; then
            echo "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" sae_password "\"$_PASS\"")   # OK"
        else
            warn "$ROLE: sae_password unsupported; falling back to psk"
            echo "+ $(mask_line wpa_cli -i "$IFACE" set_network "$NET_ID" psk "\"$_PASS\"")"
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
            echo "+ kill $PID   # hostapd for $SAP_NAME ($IFACE via pidfile)"
            kill "$PID" 2>/dev/null || true
            sleep 1
            # If still alive, try SIGKILL
            if kill -0 "$PID" 2>/dev/null; then
                echo "+ kill -9 $PID"
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
            echo "+ kill $pid   # hostapd for $SAP_NAME (matched by $IFACE|$CONF)"
            kill "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                echo "+ kill -9 $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
            killed=1
        done
    fi

    if [ "$killed" -eq 0 ]; then
        info "$SAP_NAME: no hostapd process found for iface=$IFACE (CONF=$CONF, PIDFILE=$PIDFILE)"
    else
        info "$SAP_NAME: stop requested"
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
            echo "+ wpa_cli -i $IFACE terminate"
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
            echo "+ kill $PID   # wpa_supplicant for $ROLE ($IFACE via pidfile)"
            kill "$PID" 2>/dev/null || true
            sleep 1
            if kill -0 "$PID" 2>/dev/null; then
                echo "+ kill -9 $PID"
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
            echo "+ kill $pid   # wpa_supplicant for $ROLE ($IFACE matched by ps)"
            kill "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                echo "+ kill -9 $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
            killed=1
        done
    fi

    if [ "$killed" -eq 0 ]; then
        info "$ROLE: no wpa_supplicant process found for $IFACE"
    else
        info "$ROLE: stop requested"
    fi
}

# -------- CLI parsing --------

usage() {
cat <<'EOF'
Usage (examples):

# Only SAP1:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1 -SAP1_band <2g|5g|6g> [-SAP1_ssid <ssid>]

# SAP1 + SAP2:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>]

# SAP1 + SAP2 + SAP3 + STA1:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2,SAP3 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] \
     -SAP3_band <band> [-SAP3_ssid <ssid>] \
     -STA_interfaces STA1 -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN>

# STA1 only:
  sh ./wlan_sap_sta_setup.sh -reload_driver n -STA_interfaces STA1 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN>

# STA1 + STA2:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -STA_interfaces STA1,STA2 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN> \
     -STA2_ssid <ssid> -STA2_password <pwd> -STA2_security <WPA2|WPA3|OPEN>

# Mix SAP and STA:
  sh ./wlan_sap_sta_setup.sh -reload_driver y -SAP_interfaces SAP1,SAP2,SAP3 \
     -SAP1_band <band> [-SAP1_ssid <ssid>] \
     -SAP2_band <band> [-SAP2_ssid <ssid>] \
     -SAP3_band <band> [-SAP3_ssid <ssid>] \
     -STA_interfaces STA1,STA2 \
     -STA1_ssid <ssid> -STA1_password <pwd> -STA1_security <WPA2|WPA3|OPEN> \
     -STA2_ssid <ssid> -STA2_password <pwd> -STA2_security <WPA2|WPA3|OPEN>

# Stop selected interfaces (no driver reload):
  sh ./wlan_sap_sta_setup.sh -stop SAP1,STA2

Notes:
- Config paths are per-interface:
    hostapd:        /data/hostapd_<iface>.conf
    wpa_supplicant: /data/wpa_supplicant_<iface>.conf
- Environment overrides for SAP:
    COUNTRY=US  CH2G=6  CH5G=36  VHT_SEG0_5G=50  CH6G=77
EOF
}

# Defaults
RELOAD_DRIVER="n"
SAP_LIST=""
STA_LIST=""
STOP_LIST=""

# Per-interface params
SAP1_BAND=""; SAP1_SSID=""
SAP2_BAND=""; SAP2_SSID=""
SAP3_BAND=""; SAP3_SSID=""

STA1_SSID=""; STA1_PW=""; STA1_SEC=""
STA2_SSID=""; STA2_PW=""; STA2_SEC=""

# Parse
while [ "$#" -gt 0 ]; do
  case "$1" in
    -reload_driver) RELOAD_DRIVER="$2"; shift 2;;
    -SAP_interfaces) SAP_LIST="$2"; shift 2;;
    -STA_interfaces) STA_LIST="$2"; shift 2;;

    -SAP1_band)  SAP1_BAND="$2"; shift 2;;
    -SAP1_ssid)  SAP1_SSID="$2"; shift 2;;
    -SAP2_band)  SAP2_BAND="$2"; shift 2;;
    -SAP2_ssid)  SAP2_SSID="$2"; shift 2;;
    -SAP3_band)  SAP3_BAND="$2"; shift 2;;
    -SAP3_ssid)  SAP3_SSID="$2"; shift 2;;

    -STA1_ssid)      STA1_SSID="$2"; shift 2;;
    -STA1_password)  STA1_PW="$2";  shift 2;;
    -STA1_security)  STA1_SEC="$2"; shift 2;;
    -STA2_ssid)      STA2_SSID="$2"; shift 2;;
    -STA2_password)  STA2_PW="$2";  shift 2;;
    -STA2_security)  STA2_SEC="$2"; shift 2;;

    -stop) STOP_LIST="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 2;;
  esac
done

# Validate reload_driver
case "$RELOAD_DRIVER" in y|n) : ;; *) err "-reload_driver must be y or n"; exit 2;; esac

# -------- Step 1: Detect chip (and optionally reload) --------
if ! detect_chip; then
    # If user only requested -stop, continue; else abort
    if [ -n "$STOP_LIST" ] && [ -z "$SAP_LIST$STA_LIST" ]; then
        warn "Chip detection failed but proceeding with -stop operations"
    else
        exit 1
    fi
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
                sap_start "SAP1" "$SAP1_IF" "$SAP1_BAND" "$SAP1_SSID" || FAILS=$((FAILS+1))
            fi
          ;;
          SAP2)
            if [ -z "$SAP2_BAND" ]; then warn "SAP2 requested but -SAP2_band missing"; FAILS=$((FAILS+1)); else
                sap_start "SAP2" "$SAP2_IF" "$SAP2_BAND" "$SAP2_SSID" || FAILS=$((FAILS+1))
            fi
          ;;
          SAP3)
            if [ -z "$SAP3_BAND" ]; then warn "SAP3 requested but -SAP3_band missing"; FAILS=$((FAILS+1)); else
                sap_start "SAP3" "$SAP3_IF" "$SAP3_BAND" "$SAP3_SSID" || FAILS=$((FAILS+1))
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
                sta_connect "STA1" "$STA1_IF" "$STA1_SSID" "$STA1_PW" "$STA1_SEC" 10 0 || FAILS=$((FAILS+1))
            fi
          ;;
          STA2)
            if [ -z "$STA2_SSID" ] || [ -z "$STA2_SEC" ]; then
                warn "STA2 requires -STA2_ssid and -STA2_security"; FAILS=$((FAILS+1))
            else
                sta_connect "STA2" "$STA2_IF" "$STA2_SSID" "$STA2_PW" "$STA2_SEC" 10 0 || FAILS=$((FAILS+1))
            fi
          ;;
          *) warn "Unknown STA interface: $sta"; FAILS=$((FAILS+1)) ;;
        esac
    done
fi

# -------- Step 4: Show which interfaces are UP --------
show_up_interfaces_table

# Final status
if [ "$FAILS" -gt 0 ]; then
    warn "Completed with $FAILS failure(s). See logs above for details."
    exit 1
else
    info "All requested interfaces started successfully."
    exit 0
fi
