SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

QCACLD32-LL = ""
QCACLD32-LL:qcs610-odk-64 = "qcacld32-ll-qcs610"

WLAN_PLATFORM=""
WLAN_PLATFORM:qcs610-odk-64="wlan-platform"

RDEPENDS:packagegroup-qti-wifi = " \
        ${QCACLD32-LL} \
        iw \
        ${WLAN_PLATFORM} \
        wlan-conf \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        "
