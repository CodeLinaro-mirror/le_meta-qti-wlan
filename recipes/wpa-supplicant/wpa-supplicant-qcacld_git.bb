inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.2"
PV = "6.0"
PACKAGE_ARCH = "${MACHINE_ARCH}"
MACHINE_CONFIG = "${BASEMACHINE}"
MACHINE_CONFIG:pineapple = "kalama"
MACHINE_CONFIG:qcm2290-mtp = "kalama"
MACHINE_CONFIG:kera = "kalama"
MACHINE_CONFIG:sun = "kalama"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://${MACHINE_CONFIG}/"
SRC_URI += "file://misc/"
SRC_URI:append:neo = " file://${BASEMACHINE}/"

DEPENDS += "glib-2.0 wpa-supplicant-8-lib dbus liblog qmi-framework"
DEPENDS:append:sdxlemur = "qmi"
DEPENDS:remove:neo = "qmi-framework"
DEPENDS:remove:ar-sg1 = "qmi-framework"


FILES:${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

LDFLAGS:append:neo = " -Wl,--no-as-needed -L${RECIPE_SYSROOT}/usr/lib -llog"
CFLAGS:append:neo =" -DCONFIG_ANDROID_LOG"
EXTRA_OEMAKE:append:ar-sg1 = " CONFIG_OCV=y"

do_configure() {
    if [ "$(ls -A "${WORKDIR}/${MACHINE_CONFIG}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE_CONFIG}"
        bbwarn "============================================================"
        install -m 0644 ${WORKDIR}/${MACHINE_CONFIG}/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        install -m 0644 ${WORKDIR}/misc/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    fi
}

do_configure:neo() {
    bbwarn "============================================================"
    bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
    bbwarn "============================================================"
    install -m 0644 ${WORKDIR}/${BASEMACHINE}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    rm -rf ${STAGING_LIBDIR}/libwpa_supplicant_8_lib.so*
    echo "EXTRALIBS +=\"-llog\"" >> .config
    echo "LIBS +=\"-llog\"" >> .config
}

do_configure:append:sdxlemur() {
    echo "CONFIG_EAP_PROXY=qmi" >> .config
    echo "CONFIG_EAP_PROXY_DUAL_SIM := true" >> .config
    echo "CONFIG_EAP_PROXY_AKA_PRIME := true" >> .config
    echo "CONFIG_WEP=y" >> .config
}

do_patch() {
    cd ${PATCH_DIR}
    if [ "$(ls -A "${WORKDIR}/${MACHINE_CONFIG}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE_CONFIG}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${MACHINE_CONFIG}/p2p_tmp_config.patch
        patch -p1 < ${WORKDIR}/${MACHINE_CONFIG}/driver_cmd.patch
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/misc/p2p_tmp_config.patch
        patch -p1 < ${WORKDIR}/misc/driver_cmd.patch
    fi
}

do_patch:neo() {
    cd ${PATCH_DIR}
    if [ "$(ls -A "${WORKDIR}/${BASEMACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${BASEMACHINE}/driver_cmd.patch
    fi
}

do_install:append:kalama(){
      install -d ${D}/etc/dbus-1/system.d/
      install -m 0644 ${S}/dbus/dbus-wpa_supplicant.conf -D ${D}/etc/dbus-1/system.d/dbus-wpa_supplicant.conf
}
