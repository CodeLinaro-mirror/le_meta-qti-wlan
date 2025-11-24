inherit linux-kernel-base deploy

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC & BSD-3-Clause & GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d \
                    file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9 \
                    file://${COREBASE}/meta/files/common-licenses/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

EXTRA_OEMAKE += "KERNEL_SRC=${STAGING_KERNEL_DIR} KCFLAGS='-D__ANDROID_COMMON_KERNEL__'"
TARGET_WLAN_CHIP:vienna = "themisto"
MODULE_NAME = "wlan"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
PV = "2.0"
DEPENDS += "wlan-platform-vienna-le"
WLAN_VAR:vienna = "vienna"

do_configure[depends] += "virtual/kernel:do_shared_workdir"

# TODO: Remove this local definition once available via machine.conf
#KERNEL_DEFCONFIG ?= "vienna.config"
#KERNEL_DEFCONFIG_qti-distro-debug ?= "vienna-debug_defconfig"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://device/qcom/wlan/${WLAN_VAR}/"
SRC_URI += "file://${BASEMACHINE}/wlan_load.conf"
SRC_URI += "file://${BASEMACHINE}/WCNSS_qcom_cfg.ini"
SRC_URI += "file://wlan/platform/"
SRC_URI += "file://qcacld-kbuild.patch"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn"
S2 = "${WORKDIR}/wlan/platform/"
S = "${WORKDIR}/wlan/qcacld-3.0"

FIRMWARE_PATH = "${base_libdir}/firmware/wlan/qca_cld"

#WLAN_CONFIG = "${TARGET_WLAN_CHIP}"

KERNEL_VERSION = "${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_ALLOW_OVERLAP_FILES.
SSTATE_ALLOW_OVERLAP_FILES += "${STAGING_DIR}/${BASEMACHINE}${includedir}/qcacld/wlan_nlink_common.h"

do_compile[depends] += "virtual/kernel:do_shared_workdir"
do_compile[cleandirs] += "${WORKDIR}/out/${KERNEL_DEFCONFIG}"
do_compile() {
    cd ${WORKSPACE}/kernel-${PREFERRED_VERSION_linux-msm}/kernel_platform
    BUILD_CONFIG=${KERNEL_BUILD_CONFIG} \
    EXT_MODULES=../../wlan/qcacld-3.0 \
    ENABLE_DDK_BUILD=${DDK_BUILD} \
    TARGET_BOARD_PLATFORM="${TARGET_BOARD_PLATFORM}" \
    VARIANT=${KERNEL_VARIANT} \
    MODULE_OUT=${WORKDIR}/wlan/platform \
    OUT_DIR=${KERNEL_OUT_PATH}/ \
    WLAN_BASEMACHINE=${WLAN_VAR} \
    ./build/build_module.sh \
    WLAN_PROFILE=${MODULE_NAME} \
    DYNAMIC_SINGLE_CHIP= \
    MODNAME=${MODULE_NAME}\
    DEVNAME=${MODULE_NAME} \
    BOARD_PLATFORM=${BASEMACHINE} \
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
    BUILD_DEBUG_VERSION=y \
    CONFIG_CNSS_GENL=m \
    KBUILD_EXTRA_SYMBOLS=${STAGING_DIR_HOST}/usr/lib/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers
}

do_patch() {
    cd ${S}
    patch -p1 < ${WORKDIR}/qcacld-kbuild.patch
}

do_install() {
    install -d ${S}/unstripped
    install -m 0755 ${S2}/${MODULE_NAME}.ko -D ${S}/unstripped

    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}
    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/

    ${STAGING_DIR_NATIVE}/usr/bin/aarch64-oe-linux/aarch64-oe-linux-strip \
             --strip-debug ${S}/unstripped/${MODULE_NAME}.ko -o ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/${MODULE_NAME}.ko

    #auto load
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0755 ${WORKDIR}/${BASEMACHINE}/wlan_load.conf -D ${D}${sysconfdir}/modules-load.d/wlan_load.conf

    install -d ${D}${FIRMWARE_PATH}
    install -m 0644 ${WORKDIR}/${BASEMACHINE}/WCNSS_qcom_cfg.ini ${D}${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/${MODULE_NAME}.ko ${DEPLOYDIR}/kernel_modules
}

FILES:${PN} += "${sysconfdir}/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/*"
FILES:${PN} += "${base_libdir}/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini"

addtask do_deploy after do_install
