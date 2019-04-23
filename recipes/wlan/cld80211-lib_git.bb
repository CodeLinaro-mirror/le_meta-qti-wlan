inherit autotools qcommon qlicense qprebuilt

DESCRIPTION = "CNSS"
PR = "r2"

DEPENDS = "libcutils libnl liblog"

FILESPATH =+ "${WORKSPACE}/hardware/qcom/:"

SRC_URI = "file://wlan/cld80211-lib/"

S = "${WORKDIR}/wlan/cld80211-lib"

CFLAGS += "-I ${STAGING_INCDIR}/libnl3"
CFLAGS += "-I ${WORKSPACE}/system/core/include/"
