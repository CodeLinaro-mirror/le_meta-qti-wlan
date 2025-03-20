inherit pkgconfig
include wpa-supplicant.inc
LICENSE = "BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta-qti-bsp/files/common-licenses/${LICENSE};md5=3771d4920bd6cdb8cbdf1e8344489ee0"

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"
SRC_URI += "file://p2p_tmp_config.patch"
SRC_URI += "file://driver_cmd.patch"
SRC_URI += "file://driver_cmd_ks-3.0.patch"
SRC_URI += "file://driver_cmd_ks-4.0.patch"
SRC_URI:append:qcs6490 += "file://${BASEMACHINE}"

DEPENDS += "qmi"
DEPENDS += "qmi-framework"
DEPENDS += "diag configdb dsutils common glib-2.0 time-genoff xmllib wpa-supplicant-8-lib"

FILES:${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"
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
    patch -p1 < ${WORKDIR}/p2p_tmp_config.patch
    if [ ${BASEMACHINE} == "qrbx210" ]; then
        patch -p1 < ${WORKDIR}/driver_cmd_ks-3.0.patch
    elif [ ${BASEMACHINE} == "sdmsteppe" ]; then
        patch -p1 < ${WORKDIR}/driver_cmd_ks-4.0.patch
    elif [ ${BASEMACHINE} == "qcs6490" ]; then
        patch -p1 < ${WORKDIR}/${BASEMACHINE}/driver_cmd.patch
    else
        patch -p1 < ${WORKDIR}/driver_cmd.patch
    fi
}
