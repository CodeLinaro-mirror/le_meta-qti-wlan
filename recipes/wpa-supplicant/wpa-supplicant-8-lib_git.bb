inherit autotools-brokensep pkgconfig qprebuilt

DESCRIPTION = "CNSS"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r2"

DEPENDS += "libcutils libnl liblog"

FILESPATH =+ "${WORKSPACE}/hardware/qcom/:"
WPA_SUPPLICANT_DIR = "${WORKSPACE}/external/wpa_supplicant_8/"

SRC_URI = "file://wlan/qcwcn/wpa_supplicant_8_lib/"
SRC_URI += "file://modify-makefile-to-fix-compile-issue-on-LE.patch"
SRC_URI += "file://modify_makefile.patch"
PACKAGE_ARCH ?= "${MACHINE_ARCH}"

S = "${WORKDIR}/wlan/qcwcn/wpa_supplicant_8_lib"
PATCH_DIR = "${WORKDIR}/wlan/"

do_patch() {
    cd ${PATCH_DIR}
if [ ${BASEMACHINE} == "qrbx210" ]; then
    patch -p1 < ${WORKDIR}/modify-makefile-to-fix-compile-issue-on-LE.patch
elif [ ${BASEMACHINE} == "qcs6490" ]; then
    patch -p1 < ${WORKDIR}/modify-makefile-to-fix-compile-issue-on-LE.patch
elif [ ${BASEMACHINE} == "sdmsteppe" ]; then
    patch -p1 < ${WORKDIR}/modify_makefile.patch
fi
}

CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/common"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/drivers"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/l2_packet"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/utils"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/wps"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/wpa_supplicant"
CFLAGS += "-I ${STAGING_INCDIR}/libnl3"
CFLAGS += "-DLINUX_EMBEDDED"
