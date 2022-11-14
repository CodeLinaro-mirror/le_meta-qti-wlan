SUMMARY = "QTI package group for wlan"

LICENSE = "BSD-3-Clause-Clear"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PACKAGES = "\
    packagegroup-qti-wlan \
    "

ALLOW_EMPTY_${PN} = "1"

ROMEONLY ?= 'False'
ROMEONLY_sa525m = 'True'
ROMEONLY_sa410m = 'True'

RDEPENDS_${PN} += "\
    rfkill \
    hostap-daemon-qcacld \
    wireless-tools \
    iw \
    ${@oe.utils.conditional('PREFERRED_VERSION_linux-msm', '5.15', 'wlan-platform-dlkm', '', d)} \
    ${@oe.utils.conditional('ROMEONLY', 'False', 'qcacld32-ll-rome qcacld32-ll-hasting qcacld32-ll-genoa qcacld32-ll-hsp', 'qcacld32-ll-rome', d)} \
    qcacld32-cnss2 \
    wpa-supplicant-qcacld \
    wlan-conf \
    wlan-sigma-dut \
    "
