SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

QCACLD32-LL ?= "qcacld32-ll"
QCACLD32-LL_qcs6490 = "qcacld32-ll qcacld32-ll-msl"
RDEPENDS_packagegroup-qti-wifi = " \
        ${QCACLD32-LL} \
        iw \
        wlan-conf \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        "
