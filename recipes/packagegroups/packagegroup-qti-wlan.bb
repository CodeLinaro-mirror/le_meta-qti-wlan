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
    wlan-platform-dlkm \
    wireless-tools \
    iw \
    qcacld32-cnss2 \
    wpa-supplicant-qcacld \
    wlan-conf \
    "
