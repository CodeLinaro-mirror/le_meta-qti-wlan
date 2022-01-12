inherit pkgconfig logging

include hostap-daemon.inc

PR = "${INC_PR}.2"

PACKAGE_ARCH = "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://${MACHINE}/"
SRC_URI += "file://misc/"
DEPENDS = "pkgconfig libnl openssl wpa-supplicant-8-lib liblog"

LDFLAGS +="-L${RECIPE_SYSROOT}/usr/lib -llog"

S = "${WORKDIR}/external/wpa_supplicant_8/hostapd/"
PATCH_DIR = "${WORKDIR}/external/wpa_supplicant_8/"

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

do_configure_append_sdxlemur() {
    echo "CONFIG_WEP=y" >> .config
}

do_patch() {
    cd ${PATCH_DIR}

    if [ "$(ls -A "${WORKDIR}/${MACHINE}")" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${MACHINE}/hostapd_driver_cmd.patch
    else
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/misc/hostapd_driver_cmd.patch
    fi
}
