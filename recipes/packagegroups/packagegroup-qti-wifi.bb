SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

QCACLD32_LL="qcacld32-ll"
QCACLD32_LL:neo="qcacld32-ll-neo-kiwi"
QCACLD32_LL:kalama="qcacld32-ll-kiwi"
QCACLD32_LL:qrb5165="qcacld32-ll-hst"
QCACLD32_LL:qcs40x="${@bb.utils.contains('DEBUG_BUILD', '1', "qcacld32-ll-debug", "qcacld32-ll-qcs40x", d)}"
QCACLD32_LL:pineapple="qcacld32-ll-kiwi"
QCACLD32_LL:qcm2290-mtp="${@bb.utils.contains('DEBUG_BUILD', '1', "qcacld32-ll-debug", "qcacld32-ll-qcs40x", d)}"
QCACLD32_LL:ar-sg1="qcacld32-ar-sg1"
QCACLD32_LL:kera="qcacld32-ll-debug qcacld32-ll-cologne"
QCACLD32_LL:sun="qcacld32-ll-peach"
QCACLD32_LL:alor="qcacld32-ll-debug"
QCACLD32_LL:vienna="qcacld32-ll-vienna-le"

WLAN_PLATFORM="wlan-platform"
WLAN_PLATFORM:vienna="wlan-platform-vienna-le"

WLAN_CONF="wlan-conf"
WLAN_CONF:vienna="wlan-conf-vienna"

WLAN_DEVICETREE_BB="wlan-devicetree"
WLAN_DEVICETREE_BB:ar-sg1="wlan-devicetree-ar-sg1"

# default WLAN and network software package
RDEPENDS:packagegroup-qti-wifi:append = "iw rfkill dnsmasq iperf2 iperf3 tcpdump"

RDEPENDS:packagegroup-qti-wifi:append:neo = "tcpdump dhcpcd"
RDEPENDS:packagegroup-qti-wifi:remove:qcs40x = "dnsmasq"
RDEPENDS:packagegroup-qti-wifi:remove:qcm2290-mtp = "dnsmasq"
RDEPENDS:packagegroup-qti-wifi:append:vienna = " wifi-hal"

RDEPENDS:packagegroup-qti-wifi = " \
        ${WLAN_DEVICETREE_BB} \
        ${QCACLD32_LL} \
        ${WLAN_PLATFORM} \
        ${WLAN_CONF} \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        cld80211-lib \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        "
