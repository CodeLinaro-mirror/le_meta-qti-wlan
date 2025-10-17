inherit pkgconfig

include hostap-daemon.inc

PR = "${INC_PR}.2"
PV = "6.0"
PACKAGE_ARCH = "${MACHINE_ARCH}"
MACHINE_CONFIG = "${BASEMACHINE}"
MACHINE_CONFIG:pineapple = "kalama"
MACHINE_CONFIG:qcm2290-mtp = "kalama"
MACHINE_CONFIG:kera = "kalama"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://${MACHINE_CONFIG}/"
SRC_URI += "file://misc/"
SRC_URI:append:ar-sg1 = " file://${MACHINE}/"
DEPENDS = "pkgconfig libnl openssl wpa-supplicant-8-lib liblog"

LDFLAGS +="-L${RECIPE_SYSROOT}/usr/lib -llog"
CFLAGS:append:neo =" -DCONFIG_ANDROID_LOG"

S = "${WORKDIR}/external/wpa_supplicant_8/hostapd/"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

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

do_configure:ar-sg1() {
    bbwarn "============================================================"
    bbwarn "picking ${WORKDIR}/${MACHINE}"
    bbwarn "============================================================"
    install -m 0644 ${WORKDIR}/${MACHINE}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
}

do_configure:append:sdxlemur() {
    echo "CONFIG_WEP=y" >> .config
}

do_configure:append:neo() {
    echo "LIBS_c +=-llog" >> .config
    echo "LIBS +=-llog" >> .config
}

do_patch() {
    cd ${PATCH_DIR}

    if [ "$(ls -A "${WORKDIR}/${MACHINE_CONFIG}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE_CONFIG}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${MACHINE_CONFIG}/hostapd_driver_cmd.patch
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/misc/hostapd_driver_cmd.patch
    fi
}

do_patch:ar-sg1() {
    cd ${PATCH_DIR}

    bbwarn "============================================================"
    bbwarn "picking ${WORKDIR}/${MACHINE}"
    bbwarn "============================================================"
    patch -p1 < ${WORKDIR}/${MACHINE}/hostapd_driver_cmd.patch
}
