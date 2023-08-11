inherit pkgconfig logging

include hostap-daemon.inc

PR = "${INC_PR}.2"
PV = "6.0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://${BASEMACHINE}/"
SRC_URI += "file://misc/"
DEPENDS = "pkgconfig libnl openssl wpa-supplicant-8-lib liblog"

LDFLAGS +="-L${RECIPE_SYSROOT}/usr/lib -llog"
CFLAGS:append:sxrneo +="-DCONFIG_ANDROID_LOG"

S = "${WORKDIR}/external/wpa_supplicant_8/hostapd/"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

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
    echo "CONFIG_WEP=y" >> .config
}

do_configure:append:sxrneo() {
    echo "LIBS_c +=-llog" >> .config
    echo "LIBS +=-llog" >> .config
}

do_patch() {
    cd ${PATCH_DIR}

    if [ "$(ls -A "${WORKDIR}/${BASEMACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${BASEMACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${BASEMACHINE}/hostapd_driver_cmd.patch
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/misc/hostapd_driver_cmd.patch
    fi
}
