WLAN_BB = 'autotools-brokensep module qperf'
WLAN_BB:remove:sa535m = 'qperf'
inherit ${WLAN_BB}

LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

_LINUX_BUILD_TOP = "${WORKDIR}/wlan"
EXTRA_OEMAKE:append = " LINUX_BUILD_TOP=${_LINUX_BUILD_TOP}"
