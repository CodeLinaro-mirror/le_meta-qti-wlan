SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

WLAN_IW_TOOL="${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', 'iw-wifi6e', 'iw', d)}"
QCACLD32_LL="${@oe.utils.conditional('BASEMACHINE', 'neo', 'qcacld32-ll-oot', 'qcacld32-ll', d)}"

RDEPENDS_packagegroup-qti-wifi_append_sxrneo = "tcpdump rfkill dnsmasq dhcpcd"

RDEPENDS_packagegroup-qti-wifi = " \
        ${QCACLD32_LL} \
        ${WLAN_IW_TOOL} \
        wlan-conf \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        "
