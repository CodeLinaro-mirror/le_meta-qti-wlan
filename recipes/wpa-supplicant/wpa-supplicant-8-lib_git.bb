inherit autotools-brokensep pkgconfig qprebuilt

HOMEPAGE         = "http://support.cdmatech.com"
LICENSE          = "Qualcomm-Technologies-Inc.-Proprietary"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta-qti-bsp-prop/files/qcom-licenses/\
${LICENSE};md5=92b1d0ceea78229551577d4284669bb8"

DESCRIPTION = "CNSS"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r2"

DEPENDS += "libcutils libnl liblog"

FILESPATH =+ "${WORKSPACE}/hardware/qcom/:"
WPA_SUPPLICANT_DIR = "${WORKSPACE}/external/wpa_supplicant_8/"

SRC_URI = "file://wlan/qcwcn/wpa_supplicant_8_lib/"
PACKAGE_ARCH ?= "${MACHINE_ARCH}"

S = "${WORKDIR}/wlan/qcwcn/wpa_supplicant_8_lib"

CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/common"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/drivers"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/l2_packet"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/utils"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/src/wps"
CFLAGS += "-I ${WPA_SUPPLICANT_DIR}/wpa_supplicant"
CFLAGS += "-I ${STAGING_INCDIR}/libnl3"
CFLAGS += "-DLINUX_EMBEDDED"
