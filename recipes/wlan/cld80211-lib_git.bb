inherit autotools-brokensep pkgconfig qprebuilt

DESCRIPTION = "CLD80211 LIB"
LICENSE = "BSD-3-Clause & BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"
LIC_FILES_CHKSUM += "file://${COMMON_LICENSE_DIR}/BSD-3-Clause-Clear;md5=7a434440b651f4a472ca93716d01033a"

PR = "r2"
PV = "7.1"

DEPENDS += "libcutils libnl liblog"

PACKAGE_ARCH = "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}/:"

SRC_URI = "file://hardware/qcom/wlan/cld80211-lib"

S = "${WORKDIR}/hardware/qcom/wlan/cld80211-lib"

CFLAGS += "-I ${STAGING_INCDIR}/libnl3"
