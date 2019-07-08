SUMMARY = "WLAN opensource package groups"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PACKAGES = " \
    packagegroup-wlan \
    packagegroup-wlan-debug \
    "

RDEPENDS_packagegroup-wlan = " \
    qcacld32-ll \
    hostap-daemon-qcacld \
    wpa-supplicant-qcacld \
    wpa-supplicant-8-lib \
    cld80211-lib \
    wlan-conf \
    "
RDEPENDS_packagegroup-wlan-debug = " \
    qcacld32-ll-nf-debug \
    "
