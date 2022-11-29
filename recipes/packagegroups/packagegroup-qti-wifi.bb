SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

WLAN_IW_TOOL="${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', 'iw-wifi6e', 'iw', d)}"
QCACLD32_LL="qcacld32-ll"
QCACLD32_LL:neo="qcacld32-ll-oot qcacld32-ll-kiwi"
QCACLD32_LL:kalama="qcacld32-ll-kiwi"

WLAN_PLATFORM="${@oe.utils.conditional('BASEMACHINE', 'kalama', 'wlan-platform', '', d)}"

RDEPENDS:packagegroup-qti-wifi:append:sxrneo = "tcpdump rfkill dnsmasq dhcpcd iperf2 iperf3"
RDEPENDS:packagegroup-qti-wifi:append:kalama = "rfkill dnsmasq iperf2"

RDEPENDS:packagegroup-qti-wifi = " \
        ${QCACLD32_LL} \
        ${WLAN_IW_TOOL} \
        ${WLAN_PLATFORM} \
        wlan-conf \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        "
