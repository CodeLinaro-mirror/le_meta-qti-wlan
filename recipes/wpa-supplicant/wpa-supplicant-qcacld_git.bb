inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"
SRC_URI += "file://p2p_tmp_config.patch"

DEPENDS += "qmi"
DEPENDS += "qmi-framework"
DEPENDS += "diag configdb dsutils common glib-2.0 time-genoff xmllib"

FILES_${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"

PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

do_configure() {
    install -m 0644 ${WORKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    eval $(awk '$2=="VERSION_STR" {printf("WAP_VER=%s;",$3)}' ${WORKDIR}/external/wpa_supplicant_8/src/common/version.h)
    if [ $WAP_VER == "2.9-devel" ]; then
        echo "CONFIG_OWE=y" >>.config
        echo "CONFIG_SAE=y" >>.config
        echo "CONFIG_SUITEB192=y" >>.config
        echo "CONFIG_SUITEB=y" >>.config
        echo "CONFIG_DRIVER_NL80211_QCA=y" >>.config
    fi
}
do_patch() {
    cd ${PATCH_DIR}
    patch -p1 < ${WORKDIR}/p2p_tmp_config.patch
}

INCSUFFIX ?= "none"
INCSUFFIX_automotive = "wpa-supplicant_auto"
include ${INCSUFFIX}.inc
