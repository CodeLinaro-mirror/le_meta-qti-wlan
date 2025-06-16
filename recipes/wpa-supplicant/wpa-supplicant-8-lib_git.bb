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
SRC_URI += "file://misc/"

PACKAGE_ARCH ?= "${MACHINE_ARCH}"

S = "${WORKDIR}/wlan/qcwcn/wpa_supplicant_8_lib"

PATCH_DIR = "${WORKDIR}/wlan/qcwcn/wpa_supplicant_8_lib"

CFLAGS:append= " -fcommon  -lcutils "

do_patch() {
    cd ${PATCH_DIR}

    if [[ ${MACHINE} == "sxrneo" || ${MACHINE} == "sxrneo-ar-sg1" ]]
    then
        bbwarn "============================================================"
        bbwarn "picking ${WORKDIR}/misc"
        bbwarn "============================================================"
        patch -p1 < ${WORKDIR}/misc/0001-wpa_supplicant_8_lib-Remove-deprecated-send_and_recv.patch
    fi
}
