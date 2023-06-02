inherit pkgconfig logging
include wpa-supplicant.inc

PR = "${INC_PR}.2"
PV = "6.0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://${BASEMACHINE}/"
SRC_URI += "file://misc/"

DEPENDS += "glib-2.0 wpa-supplicant-8-lib dbus liblog"
DEPENDS:append:kalama = " qmi-framework "
DEPENDS:append:sdxlemur = " qmi qmi-framework"
DEPENDS:append:qrb5165 = " qmi-framework "

FILES:${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

LDFLAGS:append:sxrneo = " -Wl,--no-as-needed -L${RECIPE_SYSROOT}/usr/lib -llog"
CFLAGS:append:sxrneo ="-DCONFIG_ANDROID_LOG"

do_configure() {
    if [ "$(ls -A "${WORKDIR}/${BASEMACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
        bbwarn "============================================================"
        install -m 0644 ${WORKDIR}/${BASEMACHINE}/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        install -m 0644 ${WORKDIR}/misc/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    fi
}

do_configure:append:sdxlemur() {
    echo "CONFIG_EAP_PROXY=qmi" >> .config
    echo "CONFIG_EAP_PROXY_DUAL_SIM := true" >> .config
    echo "CONFIG_EAP_PROXY_AKA_PRIME := true" >> .config
    echo "CONFIG_WEP=y" >> .config
}

do_configure:append:sxrneo() {
	rm -rf ${STAGING_LIBDIR}/libwpa_supplicant_8_lib.so*
        echo "EXTRALIBS +=\"-llog\"" >> .config
        echo "LIBS +=\"-llog\"" >> .config
}

do_patch() {
    cd ${PATCH_DIR}
    if [ "$(ls -A "${WORKDIR}/${BASEMACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${BASEMACHINE}/p2p_tmp_config.patch
        patch -p1 < ${WORKDIR}/${BASEMACHINE}/driver_cmd.patch
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/misc/p2p_tmp_config.patch
        patch -p1 < ${WORKDIR}/misc/driver_cmd.patch
    fi
}

