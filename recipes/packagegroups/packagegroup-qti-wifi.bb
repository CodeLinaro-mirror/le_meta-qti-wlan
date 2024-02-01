SUMMARY = "QTI open source wlan package including wlan drivers and tools."

LICENSE = "BSD-3-Clause-Clear"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"
PACKAGES = "\
    packagegroup-qti-wifi \
    "

RDEPENDS:${PN} += "\
    rfkill \
    hostap-daemon-qcacld \
    wireless-tools \
    iw \
    ${@bb.utils.contains('MACHINE', 'sa415m', '', 'qcacld32-ll-hasting', d)} \
    qcacld32-ll-genoa \
    qcacld32-ll-rome \
    ${@bb.utils.contains('MACHINE', 'sa415m', '', 'qcacld32-ll-hsp', d)} \
    ${@bb.utils.contains('MACHINE', 'mdm9607', 'qcacld32-hl', '', d)} \
    qcacld32-cnss2 \
    wpa-supplicant-qcacld \
    wlan-conf \
    wlan-sigma-dut \
    "
RDEPENDS:${PN}:remove:mdm9607 += " qcacld32-ll-hasting qcacld32-ll-hsp qcacld32-ll-genoa qcacld32-ll-rome qcacld32-cnss2"
