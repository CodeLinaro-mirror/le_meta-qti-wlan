inherit pkgconfig

include hostap-daemon.inc
inherit pkgconfig

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"
SRC_URI += "file://hostapd_driver_cmd.patch;patchdir=${WORKDIR}/external/wpa_supplicant_8/"
DEPENDS = "pkgconfig libnl openssl wpa-supplicant-8-lib"

S = "${WORKDIR}/external/wpa_supplicant_8/hostapd/"

do_configure() {
    install -m 0644 ${WORKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
}
