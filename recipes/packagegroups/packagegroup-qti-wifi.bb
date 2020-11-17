SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

HOSTAPD_DAEMON_BB = "${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', 'hostap-daemon-qcacld-ks3', 'hostap-daemon-qcacld', d)}"

WPA_SUPPLICANT_BB = "${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', 'wpa-supplicant-qcacld-ks3', 'wpa-supplicant-qcacld', d)}"

RDEPENDS_packagegroup-qti-wifi = " \
        qcacld32-ll \
        iw \
        wlan-conf \
        wlan-sigma-dut \
        ${HOSTAPD_DAEMON_BB} \
        wpa-supplicant-8-lib \
        ${WPA_SUPPLICANT_BB} \
        "
