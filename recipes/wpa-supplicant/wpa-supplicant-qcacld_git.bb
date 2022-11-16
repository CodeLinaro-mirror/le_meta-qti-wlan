inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"
SRC_URI += "file://p2p_tmp_config.patch;patchdir=${WORKDIR}/external/wpa_supplicant_8/"
SRC_URI += "file://driver_cmd.patch;patchdir=${WORKDIR}/external/wpa_supplicant_8/"
SRC_URI += "file://le_upgrade_compatiblity.patch;patchdir=${WORKDIR}/external/wpa_supplicant_8/"

DEPENDS += "qmi"
DEPENDS += "qmi-framework"
DEPENDS += "diag configdb dsutils common glib-2.0 time-genoff xmllib wpa-supplicant-8-lib"

FILES_${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"

do_configure() {
    install -m 0644 ${WORKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/dbus-1.0\"" >> .config
}

do_install_append(){
    install -d ${D}/etc/dbus-1/system.d/
    install -m 0644 ${S}/dbus/dbus-wpa_supplicant.conf -D ${D}/etc/dbus-1/system.d/dbus-wpa_supplicant.conf
    install -d ${D}/etc/systemd/system/
    install -m 0644 ${S}/dbus/fi.w1.wpa_supplicant1.service -D ${D}/etc/systemd/system/fi.w1.wpa_supplicant1.service
}
