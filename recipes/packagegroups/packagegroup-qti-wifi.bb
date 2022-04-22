SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

WLAN_IW_TOOL="${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', 'iw-wifi6e', 'iw', d)}"

RDEPENDS_packagegroup-qti-wifi = " \
        qcacld32-ll \
        ${WLAN_IW_TOOL} \
        wlan-conf \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        "
