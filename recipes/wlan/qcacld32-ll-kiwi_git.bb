inherit linux-kernel-base deploy

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC & BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d \
                    file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"

MODULE_NAME = "kiwi_v2"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
PV = "2.0"
DEPENDS += "wlan-platform"

do_configure[depends] += "virtual/kernel:do_shared_workdir"

# TODO: Remove this local definition once available via machine.conf
KERNEL_DEFCONFIG ?= "neo_le-defconfig"
KERNEL_DEFCONFIG_qti-distro-debug ?= "neo_le-debug_defconfig"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://device/qcom/wlan/${BASEMACHINE}/"
SRC_URI += "file://wlan_load.conf"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn"
S = "${WORKDIR}/wlan/qcacld-3.0"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${TARGET_WLAN_CHIP}"

BUILD_FLAGS = "CONFIG_QCA_CLD_WLAN_PROFILE=${TARGET_WLAN_CHIP} MODNAME=${WLAN_CHIP}_${TARGET_WLAN_CHIP}"

KERNEL_VERSION="${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"

do_configure:append:sxrneo() {
    sed -i '1i DYNAMIC_SINGLE_CHIP=${TARGET_WLAN_CHIP}' ${WORKDIR}/wlan/qcacld-3.0/configs/${TARGET_WLAN_CHIP}_defconfig
    sed -i 's/CONFIG_WLAN_FEATURE_COAP := y/#CONFIG_WLAN_FEATURE_COAP := y/g' ${WORKDIR}/wlan/qcacld-3.0/configs/${TARGET_WLAN_CHIP}_defconfig
}

do_compile() {
    cd ${TOPDIR}/../src/kernel-${PREFERRED_VERSION_linux-msm}/kernel_platform && \
    BUILD_CONFIG=msm-kernel/${KERNEL_CONFIG} \
    EXT_MODULES=../../wlan/qcacld-3.0/ \
    ROOTDIR=${WORKSPACE}/ \
    MODULE_OUT=${S} \
    OUT_DIR=../out/msm-kernel-kalama-${KERNEL_VARIANT}/ \
    KERNEL_UAPI_HEADERS_DIR=${STAGING_KERNEL_BUILDDIR} \
    ./build/build_module.sh \
    WLAN_PROFILE=${MODULE_NAME} \
    DYNAMIC_SINGLE_CHIP= \
    MODNAME=${MODULE_NAME}\
    DEVNAME=${MODULE_NAME} \
    BOARD_PLATFORM=kalama \
    CONFIG_QCA_CLD_WLAN=m \
    WLAN_CTRL_NAME=wlan \
    CONFIG_CNSS_OUT_OF_TREE=y \
    CONFIG_CNSS2=m \
    CONFIG_CNSS2_QMI=y \
    CONFIG_CNSS_QMI_SVC=m \
    CONFIG_CNSS_PLAT_IPC_QMI_SVC=m \
    CONFIG_CNSS_GENL=m \
    CONFIG_WCNSS_MEM_PRE_ALLOC=m \
    CONFIG_CNSS_UTILS=m \
    KERNEL_SUPPORTS_NESTED_COMPOSITES=n \
    BUILD_DEBUG_VERSION=y \
    KBUILD_EXTRA_SYMBOLS=../out/msm-kernel-kalama-${KERNEL_VARIANT}/msm-kernel/wlan-platform/Module.symvers
}

do_install() {
    install -d ${S}/unstripped
    install -m 0755 ${S}/${MODULE_NAME}.ko -D ${S}/unstripped
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}

    ${STAGING_DIR_NATIVE}/usr/libexec/aarch64-oe-linux/gcc/aarch64-oe-linux/11.3.0/strip \
             --strip-debug ${S}/unstripped/${MODULE_NAME}.ko -o ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/${MODULE_NAME}.ko

    mkdir -p ${TOPDIR}/../src/kernel-${PREFERRED_VERSION_linux-msm}/out/msm-kernel-kalama-gki/msm-kernel/${MODULE_NAME}
    cp ${WORKDIR}/wlan/qcacld-3.0/Module.symvers ${TOPDIR}/../src/kernel-${PREFERRED_VERSION_linux-msm}/out/msm-kernel-kalama-gki/msm-kernel/${MODULE_NAME}

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
