inherit autotools-brokensep linux-kernel-base pkgconfig qprebuilt

DESCRIPTION = "Wifi HAL library"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = " \
   file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"

PACKAGE_ARCH    ?= "${MACHINE_ARCH}"

PR = "r1"

CFLAGS += "-I ${STAGING_INCDIR}/cld80211-lib"
CFLAGS += "-I ${WORKSPACE}/hardware/qcom/wlan/qcwcn/wifi_hal/vendor_nan"
CFLAGS += "-I ${WORKSPACE}/hardware/qcom/wlan/qcwcn/wifi_hal/wifi_hal_ctrl"
CFLAGS  += "-include stdint.h"
CXXFLAGS += " -std=gnu++17 -include bits/stdc++.h"

DEPENDS = "diag libcutils glib-2.0 cld80211-lib"

# Machine-specific changes for ar-sg1
DEPENDS:append:ar-sg1 = " libbsd openssl"

EXTRA_OEMAKE:append:ar-sg1 = " \
    CFLAGS='${CFLAGS} -include stdint.h' \
    CXXFLAGS='${CXXFLAGS} -include bsd/stdlib.h -include bsd/string.h' \
    LDFLAGS='${LDFLAGS} -lbsd -lcutils -lcld80211 -lssl -lcrypto' \
			     "

FILESPATH =+ "${WORKSPACE}/hardware/qcom/:"

SRC_URI = "file://wlan/qcwcn/wifi_hal"

S = "${WORKDIR}/wlan/qcwcn/wifi_hal"

EXTRA_OECONF = " \
                --with-glib \
		--with-libhardware-legacy-includes=${WORKSPACE}/hardware/interfaces/wifi/legacy_headers/include \
		--with-supplicant-header-includes=${WORKSPACE}/external/wpa_supplicant_8/src/drivers \
		--with-cld80211-lib-includes=${WORKSPACE}/hardware/qcom/wlan/cld80211-lib \
		--with-libnl-includes=${WORKSPACE}/external/libnl/include \
		--with-system-core-includes=${WORKSPACE}/system/core/include \
		--with-vendor-nan-includes=${WORKSPACE}/hardware/qcom/wlan/qcwcn/wifi_hal/vendor_nan \
		--with-wifi-hal-ctrl-includes=${WORKSPACE}/hardware/qcom/wlan/qcwcn/wifi_hal/wifi_hal_ctrl \
		"
