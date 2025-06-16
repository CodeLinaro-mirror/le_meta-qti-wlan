inherit linux-kernel-base deploy

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC & BSD-3-Clause & GPL-V2"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d \
                    file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9 \
                    file://${COREBASE}/meta/files/common-licenses/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

MODULE_NAME = "wlan"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
PV = "2.0"
DEPENDS += "wlan-platform"

do_configure[depends] += "virtual/kernel:do_shared_workdir"

# TODO: Remove this local definition once available via machine.conf
KERNEL_DEFCONFIG ?= "qcs405.config"
KERNEL_DEFCONFIG_qti-distro-debug ?= "qcs405-debug_defconfig"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://device/qcom/wlan/${BASEMACHINE}/"
SRC_URI += "file://wlan_load.conf"
SRC_URI += "file://wlan/platform/"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn"
S = "${WORKDIR}/wlan/qcacld-3.0"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${TARGET_WLAN_CHIP}"

BUILD_FLAGS = "MODNAME=${WLAN_CHIP}_${TARGET_WLAN_CHIP}"
WLAN_CONFIG = "qcs40x.snoc.perf"

KERNEL_VERSION = "${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

ADDITIONAL_CONFIGS = ""
ADDITIONAL_CONFIGS:append:qcm2290-mtp = " CONFIG_CP_STATS=y "

do_configure:append:neo() {
    sed -i '1i DYNAMIC_SINGLE_CHIP=${TARGET_WLAN_CHIP}' ${WORKDIR}/wlan/qcacld-3.0/configs/${TARGET_WLAN_CHIP}_defconfig
    sed -i 's/CONFIG_WLAN_FEATURE_COAP := y/#CONFIG_WLAN_FEATURE_COAP := y/g' ${WORKDIR}/wlan/qcacld-3.0/configs/${TARGET_WLAN_CHIP}_defconfig
}

do_compile[depends] += "virtual/kernel:do_shared_workdir"
do_compile[cleandirs] += "${WORKDIR}/out/${KERNEL_DEFCONFIG}"
do_compile() {
    cd ${KERNEL_PLATFORM_PATH}
    BUILD_CONFIG=msm-kernel/${KERNEL_CONFIG} \
    EXT_MODULES=../../wlan/qcacld-3.0/ \
    ROOTDIR=${WORKDIR}/ \
    MODULE_OUT=${S} \
    OUT_DIR=../out/${KERNEL_DEFCONFIG} \
    KERNEL_UAPI_HEADERS_DIR=${STAGING_KERNEL_BUILDDIR} \
    ./build/build_module.sh \
    DYNAMIC_SINGLE_CHIP= \
    MODNAME=${MODULE_NAME}\
    DEVNAME=${MODULE_NAME} \
    BOARD_PLATFORM=qcs40x \
    CONFIG_QCA_CLD_WLAN=m \
    WLAN_CTRL_NAME=wlan \
    CONFIG_QCA_CLD_WLAN_PROFILE=${WLAN_CONFIG} \
    CONFIG_CNSS_OUT_OF_TREE=y \
    CONFIG_ICNSS2=m \
    CONFIG_CNSS_QMI_SVC=m \
    CONFIG_CNSS_PLAT_IPC_QMI_SVC=m \
    CONFIG_WLAN_TX_MON_2_0=n \
    CONFIG_WLAN_DP_LOCAL_PKT_CAPTURE=n \
    KERNEL_SUPPORTS_NESTED_COMPOSITES=n \
    CONFIG_CNSS_GENL=m \
    CONFIG_FEATURE_COEX_TPUT_SHAPING_ENABLE=y \
    KBUILD_EXTRA_SYMBOLS=${STAGING_DIR_HOST}/lib/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers \
    ${ADDITIONAL_CONFIGS}
}

do_install() {
    install -d ${S}/unstripped
    install -m 0755 ${S}/${MODULE_NAME}.ko -D ${S}/unstripped
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}

    ${STAGING_DIR_NATIVE}/usr/bin/aarch64-oe-linux/aarch64-oe-linux-strip \
             --strip-debug ${S}/unstripped/${MODULE_NAME}.ko -o ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/${MODULE_NAME}.ko

    #auto load
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0755 ${WORKDIR}/wlan_load.conf -D ${D}${sysconfdir}/modules-load.d/wlan_load.conf
}

do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/${MODULE_NAME}.ko ${DEPLOYDIR}/kernel_modules
}

FILES:${PN} += "${sysconfdir}/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/*"

addtask do_deploy after do_install
