inherit pkgconfig
include wpa-supplicant.inc

PR = "${INC_PR}.2"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/"
SRC_URI += "file://defconfig-qcacld"


FILES:${PN} += "/usr/include/*"

S = "${WORKDIR}/external/wpa_supplicant_8/wpa_supplicant"

do_configure() {
    if [ "${BASEMACHINE}" == "sa535m" ] ; then
        sed -i -e 's/^CONFIG_EAP_PROXY=qmi/#CONFIG_EAP_PROXY=qmi/g' ${WORKDIR}/defconfig-qcacld
    fi
    install -m 0644 ${WORKDIR}/defconfig-qcacld .config
    echo "CFLAGS +=\"-I${STAGING_INCDIR}/libnl3\"" >> .config
}

INCSUFFIX ?= "none"
INCSUFFIX:automotive = "wpa-supplicant_auto"
INCSUFFIX:auto = "wpa-supplicant_auto"
include ${INCSUFFIX}.inc
