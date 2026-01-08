inherit pkgconfig logging
include wpa-supplicant.inc

PR = "${INC_PR}.2"
PV = "5.0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://${@bb.utils.contains('BASEMACHINE', 'sdxlemur','${BASEMACHINE}','${MACHINE}', d)}/"
SRC_URI += "file://misc/"

DEPENDS += "glib-2.0 wpa-supplicant-8-lib dbus liblog"
DEPENDS_append_sdxlemur = " qmi qmi-framework"

FILES_${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

LDFLAGS_append_sxrneo += " -Wl,--no-as-needed"
LDFLAGS_append_sxrneo +="-L${RECIPE_SYSROOT}/usr/lib -llog"
CFLAGS_append_sxrneo +="-DCONFIG_ANDROID_LOG"

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

do_configure_sdxlemur() {
    if [ "$(ls -A "${WORKDIR}/${BASEMACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
        bbwarn "============================================================"
        install -m 0644 ${WORKDIR}/${BASEMACHINE}/defconfig-qcacld .config
        echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
    fi
}

do_configure_append_sdxlemur() {
    echo "CONFIG_EAP_PROXY=qmi" >> .config
    echo "CONFIG_EAP_PROXY_DUAL_SIM := true" >> .config
    echo "CONFIG_EAP_PROXY_AKA_PRIME := true" >> .config
    echo "CONFIG_WEP=y" >> .config
}

do_configure_append_sxrneo() {
	rm -rf ${STAGING_LIBDIR}/libwpa_supplicant_8_lib.so*
        echo "EXTRALIBS +=\"-llog\"" >> .config
        echo "LIBS +=\"-llog\"" >> .config
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

do_patch_sdxlemur() {
    cd ${PATCH_DIR}
    if [ "$(ls -A "${WORKDIR}/${BASEMACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
        bbwarn "============================================================"
        for patch in ${WORKDIR}/${BASEMACHINE}/*.patch; do
            patch -p1 < "$patch"
        done
    fi
}

do_patch_sxrneo() {
    cd ${PATCH_DIR}
    if [ "$(ls -A "${WORKDIR}/${MACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${MACHINE}/driver_cmd.patch
    fi
}
