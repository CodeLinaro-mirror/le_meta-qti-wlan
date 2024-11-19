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
DEPENDS:append:kalama:ubuntu = " cfg80211w"

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
SRC_URI += "file://wlan/platform/"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn"
S = "${WORKDIR}/wlan/qcacld-3.0"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${TARGET_WLAN_CHIP}"

BUILD_FLAGS = "CONFIG_QCA_CLD_WLAN_PROFILE=${TARGET_WLAN_CHIP} MODNAME=${WLAN_CHIP}_${TARGET_WLAN_CHIP}"

KERNEL_VERSION = "${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"
SYMVERS = "KBUILD_EXTRA_SYMBOLS=${STAGING_DIR_HOST}/lib/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers"
SYMVERS:append:kalama:ubuntu = " KBUILD_EXTRA_SYMBOLS+=${STAGING_DIR_HOST}/lib/modules/${KERNEL_VERSION}/cfg80211w/cfg80211w.symvers"
ADDITIONAL_CONFIGS = ""
ADDITIONAL_CONFIGS:append:kalama:ubuntu = " CONFIG_CFG80211_PROP_MULTI_LINK_SUPPORT=y CONFIG_NL80211_TESTMODE=y "

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
    KERNEL_KIT=${KERNEL_PREBUILT_PATH} \
    ROOTDIR=${WORKDIR}/ \
    OUT_DIR=${WORKDIR}/out/${KERNEL_DEFCONFIG} \
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
    CONFIG_WLAN_TX_MON_2_0=n \
    CONFIG_WLAN_DP_LOCAL_PKT_CAPTURE=n \
    KERNEL_SUPPORTS_NESTED_COMPOSITES=n \
    BUILD_DEBUG_VERSION=y \
    ${ADDITIONAL_CONFIGS} \
    ${SYMVERS}
}

do_install() {
    install -d ${S}/unstripped
    install -m 0755 ${S}/${MODULE_NAME}.ko -D ${S}/unstripped
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}

    ${STAGING_DIR_NATIVE}/usr/bin/aarch64-oe-linux/aarch64-oe-linux-strip \
             --strip-debug ${S}/unstripped/${MODULE_NAME}.ko -o ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/${MODULE_NAME}.ko

    install ${WORKDIR}/wlan/qcacld-3.0/Module.symvers -D ${D}${base_libdir}/modules/${KERNEL_VERSION}/wlan-kernel/Module.symvers

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
