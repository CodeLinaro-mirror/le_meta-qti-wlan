SUMMARY = "QTI package group for wlan"

LICENSE = "BSD-3-Clause-Clear"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PACKAGES = "\
    packagegroup-qti-wlan \
    "

ALLOW_EMPTY:${PN} = "1"

DRIVERS ?= 'qcacld32-ll-rome qcacld32-ll-hasting qcacld32-ll-genoa qcacld32-ll-hsp'
DRIVERS:sa410m = 'qcacld32-ll-rome'
DRIVERS:sa525m = 'qcacld32-ll-rome qcacld32-ll-hsp qcacld32-ll-hmt'
DRIVERS:sa510m = 'qcacld32-ll-rome qcacld32-hl'
DRIVERS:sa535m = 'qcacld32-ll-hmt qcacld32-ll-hsp'
DRIVERS:sa510m-1g = 'qcacld32-ll-rome qcacld32-ll-hsp'
DRIVERS:append = ' wlan-platform-dlkm'

APPS ?= 'rfkill iw wireless-tools hostap-daemon-qcacld wpa-supplicant-qcacld wlan-sigma-dut'
APPS:append:sa510m = ' iperf3 busybox-udhcpc'
APPS:append:sa510m-1g = ' iperf3 busybox-udhcpc'
APPS:append:sa535m = ' iperf3'
CONF:sa535m = 'wlan-conf'
CONF ?= 'wlan-conf qcacld32-cnss2'

RDEPENDS:${PN} += "\
    ${DRIVERS} \
    ${CONF} \
    ${APPS} \
    "
