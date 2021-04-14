inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"
SRC_URI += "file://p2p_tmp_config.patch"
SRC_URI += "file://driver_cmd.patch"
SRC_URI += "file://le_upgrade_compatiblity.patch"

DEPENDS += "glib-2.0 wpa-supplicant-8-lib dbus liblog"

FILES_${PN} += "/usr/include/*"

LDFLAGS += " -Wl,--no-as-needed"
LDFLAGS +="-L${RECIPE_SYSROOT}/usr/lib -llog"
S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

do_configure() {
    install -m 0644 ${WORKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    rm -rf ${STAGING_LIBDIR}/libwpa_supplicant_8_lib.so*
}
do_patch() {
    cd ${PATCH_DIR}
    patch -p1 < ${WORKDIR}/p2p_tmp_config.patch
    patch -p1 < ${WORKDIR}/driver_cmd.patch
    patch -p1 < ${WORKDIR}/le_upgrade_compatiblity.patch
}

