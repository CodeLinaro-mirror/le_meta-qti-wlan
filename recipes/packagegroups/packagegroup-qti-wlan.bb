SUMMARY = "QTI open source wlan package including wlan drivers and tools."

LICENSE = "BSD-3-Clause-Clear"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"
PACKAGES = "\
    packagegroup-qti-wlan \
    "

RDEPENDS_${PN} += "\
    rfkill \
    hostap-daemon-qcacld \
    wireless-tools \
    iw \
    qcacld32-ll-hasting \
    qcacld32-ll-genoa \
    qcacld32-ll-rome \
    wpa-supplicant-qcacld \
    wlan-conf \
    "
