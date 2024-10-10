inherit autotools-brokensep pkgconfig qprebuilt

DESCRIPTION = "CNSS"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r2"
PV = "7.0"
DEPENDS += "libcutils libnl liblog"

PACKAGE_ARCH = "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}/hardware/qcom/:"
WPA_SUPPLICANT_DIR = "${WORKSPACE}/external/wpa_supplicant_8/"
EXTRA_OECONF += "WPA_SUPPLICANT_DIR=${WPA_SUPPLICANT_DIR}"

SRC_URI = "file://wlan/qcwcn/wpa_supplicant_8_lib/"
SRC_URI += "file://${@bb.utils.contains('BASEMACHINE', 'sxrneo','${BASEMACHINE}','${MACHINE}', d)}/"
PACKAGE_ARCH ?= "${MACHINE_ARCH}"

S = "${WORKDIR}/wlan/qcwcn/wpa_supplicant_8_lib"
PATCH_DIR = "${WORKDIR}/wlan/qcwcn/wpa_supplicant_8_lib/"

do_patch() {
    cd ${PATCH_DIR}
    if [ -e "${WORKDIR}/${MACHINE}/Remove-deprecated-send_and_recv.patch" ]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/${MACHINE}"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/${MACHINE}/Remove-deprecated-send_and_recv.patch
    fi
}
