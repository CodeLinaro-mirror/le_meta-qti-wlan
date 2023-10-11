inherit pkgconfig

include hostap-daemon.inc
inherit pkgconfig

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"
DEPENDS = "pkgconfig libnl openssl"
SRC_URI_append_qcs6490 += "file://${BASEMACHINE}"
DEPENDS_append_qcs6490 += "wpa-supplicant-8-lib"

S = "${WORKDIR}/external/wpa_supplicant_8/hostapd/"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

do_configure() {
    if [ ${BASEMACHINE} == "qcs6490" ]; then
        install -m 0644 ${WORKDIR}/${BASEMACHINE}/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    else
        install -m 0644 ${WORKDIR}/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    fi
}

do_patch() {
    cd ${PATCH_DIR}
    if [ ${BASEMACHINE} == "qcs6490" ]; then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${BASEMACHINE}/hostapd_driver_cmd.patch
    fi
}
