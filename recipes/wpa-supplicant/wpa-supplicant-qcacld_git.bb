inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"

FILES_${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"

do_configure() {
    sed -i -e 's/^CONFIG_EAP_PROXY=qmi/#CONFIG_EAP_PROXY=qmi/g' ${WORKDIR}/defconfig-qcacld
    install -m 0644 ${WORKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
}

INCSUFFIX ?= "none"
INCSUFFIX_automotive = "wpa-supplicant_auto"
INCSUFFIX_auto = "wpa-supplicant_auto"
INCSUFFIX_sa515m = "wpa-supplicant_auto"
INCSUFFIX_sa525m = "wpa-supplicant_auto"
include ${INCSUFFIX}.inc
