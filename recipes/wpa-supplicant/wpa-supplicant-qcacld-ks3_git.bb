inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.3"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"
SRC_URI += "file://p2p_tmp_config.patch"
SRC_URI += "file://driver_cmd_ks3.patch"

DEPENDS += "glib-2.0 wpa-supplicant-8-lib"
DEPENDS_append_sdxlemur = " qmi qmi-framework"

FILES_${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

do_configure() {
    install -m 0644 ${WORKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
}

do_configure_append_sdxlemur() {
    echo "CONFIG_EAP_PROXY=qmi" >> .config
    echo "CONFIG_EAP_PROXY_DUAL_SIM := true" >> .config
    echo "CONFIG_EAP_PROXY_AKA_PRIME := true" >> .config
    echo "CONFIG_WEP=y" >> .config
}

do_patch() {
    cd ${PATCH_DIR}
    patch -p1 < ${WORKDIR}/p2p_tmp_config.patch
    patch -p1 < ${WORKDIR}/driver_cmd_ks3.patch
}

