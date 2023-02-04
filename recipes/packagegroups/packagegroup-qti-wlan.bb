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
    ${@bb.utils.contains('MACHINE', 'sa415m', '', 'qcacld32-ll-hasting', d)} \
    ${@bb.utils.contains('MACHINE', 'sa415m', '', 'qcacld32-ll-genoa', d)} \
    qcacld32-ll-rome \
    ${@bb.utils.contains('MACHINE', 'sa415m', '', 'qcacld32-ll-hsp', d)} \
    qcacld32-cnss2 \
    wpa-supplicant-qcacld \
    wlan-conf \
    "
