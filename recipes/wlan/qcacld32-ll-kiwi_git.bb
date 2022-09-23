inherit linux-kernel-base deploy

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC & BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d \
                    file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"

TARGET_WLAN_CHIP = "kiwi_v2"
WLAN_CHIP = "qca_cld3"

FILES_${PN}     += "lib/firmware/wlan/*"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko"
PROVIDES_NAME   = "kernel-module-wlan"
RPROVIDES_${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"
do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
PV = "2.0"
DEPENDS = "linux-msm-headers qcacld32-ll-oot"

do_configure[depends] += "virtual/kernel:do_shared_workdir"

# TODO: Remove this local definition once available via machine.conf
KERNEL_DEFCONFIG ?= "neo_le-defconfig"
KERNEL_DEFCONFIG_qti-distro-debug ?= "neo_le-debug_defconfig"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
#SRC_URI += "file://kernel-5.10/kernel_platform"
#SRC_URI += "file://kernel-5.10/out/${KERNEL_DEFCONFIG}"
SRC_URI += "file://device/qcom/wlan/${BASEMACHINE}/"
SRC_URI += "file://wlan_load.conf"

CLANG_BIN = "${WORKDIR}/recipe-sysroot-native/usr/bin/clang/bin"
S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"
WS = "${WORKSPACE}/wlan/qcacld-3.0/"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${TARGET_WLAN_CHIP}"

BUILD_FLAGS = "CONFIG_QCA_CLD_WLAN_PROFILE=${TARGET_WLAN_CHIP} MODNAME=${WLAN_CHIP}_${TARGET_WLAN_CHIP}"

do_configure_append_sxrneo() {
    sed -i '1i DYNAMIC_SINGLE_CHIP=${TARGET_WLAN_CHIP}' ${WORKSPACE}/wlan/qcacld-3.0/configs/${TARGET_WLAN_CHIP}_defconfig
}

do_compile() {
    cd ${WORKSPACE}/kernel-5.10/kernel_platform
    BUILD_CONFIG=msm-kernel/${KERNEL_CONFIG} \
    EXT_MODULES=../../wlan/qcacld-3.0 \
    ROOTDIR=${WORKSPACE}/ \
    DIST_DIR=${WORKSPACE}/wlan \
    UNSTRIPPED_MODULES=wlan \
    MODULE_OUT=${WORKSPACE}/wlan/qcacld-3.0 \
    OUT_DIR=${WORKSPACE}/kernel-5.10/out/${KERNEL_DEFCONFIG} \
    ./build/build_module.sh ${BUILD_FLAGS}
}

do_install() {
    KERNEL_VERSION="${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
    bbnote "Kernel Version: \"${KERNEL_VERSION}\""
    install -d ${S}/unstripped
    cp -f ${WS}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko ${S}/unstripped
    ${CLANG_BIN}/llvm-strip --strip-unneeded ${WS}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko
    install -m 0755 ${WS}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko -D ${D}/${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0755 ${WORKDIR}/wlan_load.conf -D ${D}${sysconfdir}/modules-load.d/wlan_load.conf
    install -d ${FIRMWARE_PATH}
    install -m 0644 ${WORKDIR}/device/qcom/wlan/${BASEMACHINE}/WCNSS_qcom_cfg_${TARGET_WLAN_CHIP}_LE.ini ${D}/lib/firmware/wlan/qca_cld/${TARGET_WLAN_CHIP}/WCNSS_qcom_cfg.ini
}

do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko ${DEPLOYDIR}/kernel_modules/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko
}

FILES_${PN} += "${sysconfdir}/*"
FILES_${PN} += "${nonarch_base_libdir}/modules/*"

addtask do_deploy after do_install
