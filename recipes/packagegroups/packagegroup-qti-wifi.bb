SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

WLAN_IW_TOOL="${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', 'iw-wifi6e', 'iw', d)}"
QCACLD32_LL="qcacld32-ll"
QCACLD32_LL:neo="qcacld32-ll-neo-kiwi"
QCACLD32_LL:kalama="qcacld32-ll-kiwi"
QCACLD32_LL:qrb5165="qcacld32-ll-hst"
QCACLD32_LL:qcs40x="${@bb.utils.contains('DEBUG_BUILD', '1', "qcacld32-ll-debug", "qcacld32-ll-qcs40x", d)}"
QCACLD32_LL:pineapple="qcacld32-ll-kiwi"
QCACLD32_LL:qcm2290-mtp="${@bb.utils.contains('DEBUG_BUILD', '1', "qcacld32-ll-debug", "qcacld32-ll-qcs40x", d)}"
QCACLD32_LL:ar-sg1="qcacld32-ar-sg1"
QCACLD32_LL:qcm4325-mtp="${@bb.utils.contains('DEBUG_BUILD', '1', "qcacld32-ll-debug", "qcacld32-ll-qcm4325", d)}"

WLAN_PLATFORM=""
WLAN_PLATFORM:kalama="wlan-platform"
WLAN_PLATFORM:qrb5165="wlan-platform"
WLAN_PLATFORM:qcs40x="wlan-platform"
WLAN_PLATFORM:pineapple="wlan-platform"
WLAN_PLATFORM:qcm2290-mtp="wlan-platform"
WLAN_PLATFORM:ar-sg1="wlan-platform"
WLAN_PLATFORM:qcm4325-mtp="wlan-platform"

RDEPENDS:packagegroup-qti-wifi:append:neo = "tcpdump rfkill dnsmasq dhcpcd iperf2 iperf3"
RDEPENDS:packagegroup-qti-wifi:append:kalama = "rfkill dnsmasq iperf2"
RDEPENDS:packagegroup-qti-wifi:append:qrb5165 = "rfkill dnsmasq iperf2"
RDEPENDS:packagegroup-qti-wifi:append:qcs40x = "rfkill iperf2 iperf3"
RDEPENDS:packagegroup-qti-wifi:append:pineapple = "rfkill dnsmasq iperf2"
RDEPENDS:packagegroup-qti-wifi:append:qcm2290-mtp = "rfkill iperf2 iperf3"
RDEPENDS:packagegroup-qti-wifi:append:qcm4325-mtp = "rfkill iperf2 iperf3"

RDEPENDS:packagegroup-qti-wifi = " \
        ${QCACLD32_LL} \
        ${WLAN_IW_TOOL} \
        ${WLAN_PLATFORM} \
        wlan-conf \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        wireless-tools \
        "
