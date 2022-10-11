SUMMARY = "QTI package group for wlan"

LICENSE = "BSD-3-Clause-Clear"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PACKAGES = "\
    packagegroup-qti-wlan \
    "

ALLOW_EMPTY_${PN} = "1"

RDEPENDS_${PN} += "\
    rfkill \
    hostap-daemon-qcacld \
    wireless-tools \
    iw \
    qcacld32-ll-hasting \
    qcacld32-ll-genoa \
    qcacld32-ll-rome \
    qcacld32-ll-hsp \
    wpa-supplicant-qcacld \
    wlan-conf \
    "
