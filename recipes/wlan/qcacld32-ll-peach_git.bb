inherit linux-kernel-base deploy
DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC & BSD-3-Clause & GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d \
                    file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"

MODULE_NAME = "peach_v2"
TARGET_WLAN_CONFIG:sun = "sun_gki_peach-v2"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
PV = "2.0"
DEPENDS += "wlan-platform"
DEPENDS:append:sun:linux = " cfg80211w"

do_configure[depends] += "virtual/kernel:do_shared_workdir"

# TODO: Remove this local definition once available via machine.conf
KERNEL_DEFCONFIG ?= "sun_le-defconfig"
KERNEL_DEFCONFIG_qti-distro-debug ?= "sun_le-debug_defconfig"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://device/qcom/wlan/${BASEMACHINE}/"
SRC_URI += "file://wlan_load.conf"
SRC_URI += "file://wlan/platform/"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn"
S = "${WORKDIR}/wlan/qcacld-3.0"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${MODNAME}"

KERNEL_VERSION = "${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"
SYMVERS = "KBUILD_EXTRA_SYMBOLS=${STAGING_DIR_HOST}/usr/lib/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers"
SYMVERS:append:sun:linux = " KBUILD_EXTRA_SYMBOLS+=${STAGING_DIR_HOST}/${nonarch_base_libdir}/modules/${KERNEL_VERSION}/cfg80211w/cfg80211w.symvers"
ADDITIONAL_CONFIGS = ""
ADDITIONAL_CONFIGS:append:sun:linux = " CONFIG_CFG80211_PROP_MULTI_LINK_SUPPORT=y CONFIG_NL80211_TESTMODE=y"
NOSTDINC1 = ""
NOSTDINC1:sun:linux = " NOSTDINC_FLAGS+=-I${STAGING_INCDIR}/msm-kernel/include"
NOSTDINC2 = ""
NOSTDINC2:sun:linux = " NOSTDINC_FLAGS+=-I${STAGING_INCDIR}/msm-kernel/include/uapi"
ADDITIONAL_CONFIGS:append:sun = " CONFIG_IPA_OFFLOAD=n "

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
    KBUILD_OPTIONS+="${NOSTDINC1}" \
    KBUILD_OPTIONS+="${NOSTDINC2}" \
    ./build/build_module.sh \
    DYNAMIC_SINGLE_CHIP= \
    MODNAME=${MODULE_NAME}\
    DEVNAME=${MODULE_NAME} \
    CONFIG_QCA_CLD_WLAN=m \
    WLAN_CTRL_NAME=wlan \
    CONFIG_QCA_CLD_WLAN_PROFILE=${TARGET_WLAN_CONFIG} \
    CONFIG_CNSS_OUT_OF_TREE=y \
    CONFIG_CNSS2=m \
    CONFIG_CNSS2_QMI=y \
    CONFIG_CNSS_QMI_SVC=m \
    CONFIG_CNSS_PLAT_IPC_QMI_SVC=m \
    CONFIG_CNSS_GENL=m \
    CONFIG_WCNSS_MEM_PRE_ALLOC=m \
    CONFIG_CNSS_UTILS=m \
    CONFIG_NL80211_TESTMODE=m \
    CONFIG_FEATURE_SMEM_MAILBOX=m \
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

#auto load
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0755 ${WORKDIR}/wlan_load.conf -D ${D}${sysconfdir}/modules-load.d/wlan_load.conf
    if [ "${BASEMACHINE}" = "sun" ]; then
        echo "peach_v2" > ${D}${sysconfdir}/modules-load.d/wlan_load.conf
    fi
}

do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/${MODULE_NAME}.ko ${DEPLOYDIR}/kernel_modules
}

FILES:${PN} += "${sysconfdir}/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/*"

addtask do_deploy after do_install

