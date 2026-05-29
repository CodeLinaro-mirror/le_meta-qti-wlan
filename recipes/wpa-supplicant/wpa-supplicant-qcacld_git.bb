inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"

FILES:${PN} += "/usr/include/*"

S = "${UNPACKDIR}/external/wpa_supplicant_8/wpa_supplicant"

do_configure() {
    sed -i -e 's/^CONFIG_EAP_PROXY=qmi/#CONFIG_EAP_PROXY=qmi/g' ${UNPACKDIR}/defconfig-qcacld
    install -m 0644 ${UNPACKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
}

INCSUFFIX ?= "none"
INCSUFFIX:automotive = "wpa-supplicant_auto"
INCSUFFIX:auto = "wpa-supplicant_auto"
INCSUFFIX:sa515m = "wpa-supplicant_auto"
INCSUFFIX:sa525m = "wpa-supplicant_auto"
INCSUFFIX:sa535m = "wpa-supplicant_auto"
INCSUFFIX:sa510m = "wpa-supplicant_auto"
include ${INCSUFFIX}.inc
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-dbg += "buildpaths"
