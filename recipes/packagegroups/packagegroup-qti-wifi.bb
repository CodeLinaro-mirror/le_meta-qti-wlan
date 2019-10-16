SUMMARY = "QTI WIFI opensource package groups"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = ' \
    packagegroup-qti-wifi \
    \
    ${@bb.utils.contains("COMBINED_FEATURES", "qti-wifi", bb.utils.contains("MACHINE_FEATURES", "naples", "packagegroup-qti-wifi-naples", "", d), "", d)} \
    ${@bb.utils.contains("COMBINED_FEATURES", "qti-wifi", "packagegroup-qti-wifi-tools", "", d)} \
    '

RDEPENDS_packagegroup-qti-wifi = ' \
    ${@bb.utils.contains("COMBINED_FEATURES", "qti-wifi", bb.utils.contains("MACHINE_FEATURES", "naples", "packagegroup-qti-wifi-naples", "", d), "", d)} \
    ${@bb.utils.contains("COMBINED_FEATURES", "qti-wifi", "packagegroup-qti-wifi-tools", "", d)} \
    '

RDEPENDS_packagegroup-qti-wifi-naples = " \
    qcacld-hl \
    wpa-supplicant-qcacld-naples \
    hostap-daemon-qcacld \
    "

RDEPENDS_packagegroup-qti-wifi-tools = " \
    iw \
    wlan-conf \
    wireless-tools \
    "
