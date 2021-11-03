inherit pkgconfig logging
include wpa-supplicant.inc

PR = "${INC_PR}.2"

PACKAGE_ARCH = "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://${MACHINE}/"
SRC_URI += "file://misc/"

DEPENDS += "qmi"
DEPENDS += "qmi-framework"
DEPENDS += "diag configdb dsutils common glib-2.0 time-genoff xmllib wpa-supplicant-8-lib"

FILES_${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

do_configure() {
    if [ "$(ls -A "${WORKDIR}/${MACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE}"
        bbwarn "============================================================"
        install -m 0644 ${WORKDIR}/${MACHINE}/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        install -m 0644 ${WORKDIR}/misc/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    fi
}
do_patch() {
    cd ${PATCH_DIR}
    if [ "$(ls -A "${WORKDIR}/${MACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${MACHINE}/p2p_tmp_config.patch
        patch -p1 < ${WORKDIR}/${MACHINE}/driver_cmd.patch
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/misc/p2p_tmp_config.patch
        patch -p1 < ${WORKDIR}/misc/driver_cmd.patch
    fi
}

