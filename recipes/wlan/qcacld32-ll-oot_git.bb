inherit linux-kernel-base deploy

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

FILES_${PN}     += "lib/firmware/wlan/*"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/wlan.ko"
PROVIDES_NAME   = "kernel-module-wlan"
RPROVIDES_${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"
do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
PV = "2.0"
DEPENDS = "linux-msm-headers"

do_configure[depends] += "virtual/kernel:do_shared_workdir"

# TODO: Remove this local definition once available via machine.conf
KERNEL_DEFCONFIG ?= "neo_le-defconfig"
KERNEL_DEFCONFIG_qti-distro-debug ?= "neo_le-debug_defconfig"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://kernel-5.10/kernel_platform"
SRC_URI += "file://kernel-5.10/out/${KERNEL_DEFCONFIG}"
SRC_URI += "file://wlan_load.conf"

CLANG_BIN = "${WORKDIR}/recipe-sysroot-native/usr/bin/clang/bin"
S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld"

do_configure_append_sxrneo() {
    sed -i '1i CONFIG_CLD_HL_SDIO_CORE=n' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_CNSS_SDIO=n' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_CNSS_QCA6750=y' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_WLAN_SYNC_TSF_PLUS=y' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_WLAN_SYNC_TSF_TIMER=y' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_WLAN_TWT_SAP_STA_COUNT=y' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_WLAN_TWT_SAP_PDEV_COUNT=y' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_WLAN_FEATURE_PEER_TXQ_FLUSH_CONF=y' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
    sed -i '1i CONFIG_QCA_CLD_WLAN_PROFILE=default' ${WORKDIR}/wlan/qcacld-3.0/configs/default_defconfig
}

do_compile() {
    cd ${WORKDIR}/kernel-5.10/kernel_platform  && \
    BUILD_CONFIG=msm-kernel/${KERNEL_CONFIG} \
    EXT_MODULES=../../wlan/qcacld-3.0 \
    ROOTDIR=${WORKDIR}/ \
    DIST_DIR=${WORKDIR}/wlan \
    UNSTRIPPED_MODULES=wlan \
    MODULE_OUT=${WORKDIR}/wlan/qcacld-3.0 \
    OUT_DIR=${WORKDIR}/kernel-5.10/out/${KERNEL_DEFCONFIG} \
    ./build/build_module.sh
}

do_install() {
    KERNEL_VERSION="${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
    bbnote "Kernel Version: \"${KERNEL_VERSION}\""
    install -d ${S}/unstripped
    cp -f ${S}/wlan.ko ${S}/unstripped
    ${CLANG_BIN}/llvm-strip --strip-unneeded ${S}/wlan.ko
    install -m 0755 ${S}/wlan.ko -D ${D}/${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/wlan.ko
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0755 ${WORKDIR}/wlan_load.conf -D ${D}${sysconfdir}/modules-load.d/wlan_load.conf
    install -d ${FIRMWARE_PATH}
}

do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/wlan.ko ${DEPLOYDIR}/kernel_modules/wlan.ko
}

FILES_${PN} += "${sysconfdir}/*"
FILES_${PN} += "${nonarch_base_libdir}/modules/*"

addtask do_deploy after do_install
