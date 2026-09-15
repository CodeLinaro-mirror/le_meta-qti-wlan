inherit module deploy

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

PROVIDES_NAME   = "kernel-module-wlan"
RPROVIDES:${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

DEFAULT_PREFERENCE = "-1"

TARGET_WLAN_CHIP = "peach"
WLAN_CHIP = "qca_cld3"
TARGET_WLAN_CHIP_CONFIG = "seraph_gki_peach-v2"

PR = "r8"

# This DEPENDS is to serialize kernel module builds
DEPENDS = "virtual/kernel virtual/kernel-toolchain-native kernel-module-soc-repo"
DEPENDS += "wlan-platform-peach-seraph"
DEPENDS += "soc-modules"

FILES:${PN}     += "lib/firmware/wlan/*"
FILES:${PN}     += "lib/modules/${KERNEL_VERSION}/extra/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko"
FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://device/qcom/wlan/${BASEMACHINE}/"
SRC_URI += "file://${BASEMACHINE}/wlan_load.conf"
SRC_URI += "file://wlan/platform/"
SRC_URI += "file://qcacld-kbuild.patch"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"

RPROVIDES:${PN} += "kernel-module-qca-cld3-peach-v2-${KERNEL_VERSION}"
CLANG_BIN = "${WORKDIR}/recipe-sysroot-native/usr/bin/clang/bin"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${WLAN_CHIP}_${TARGET_WLAN_CHIP}"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.

KERNEL_CC = "${STAGING_BINDIR_NATIVE}/clang/bin/clang -target ${TARGET_ARCH}${TARGET_VENDOR}-${TARGET_OS}"
BUILD_FLAGS = "WLAN_ROOT=${S} CONFIG_QCA_CLD_WLAN_PROFILE=${TARGET_WLAN_CHIP_CONFIG} MODNAME=${WLAN_CHIP}_${TARGET_WLAN_CHIP}"

ADDITIONAL_CONFIGS = "CONFIG_QCA_CLD_WLAN=m WLAN_CTRL_NAME=wlan KERNEL_SUPPORTS_NESTED_COMPOSITES=n CONFIG_CNSS_OUT_OF_TREE=y CONFIG_CNSS2=m CONFIG_CNSS2_QMI=y CONFIG_CNSS_QMI_SVC=m CONFIG_CNSS_PLAT_IPC_QMI_SVC=m CONFIG_CNSS_GENL=m CONFIG_WCNSS_MEM_PRE_ALLOC=m CONFIG_CNSS_UTILS=m CONFIG_DP_SWLM=n CONFIG_SHUTDOWN_WLAN_IN_SYSTEM_SUSPEND=y"

do_compile:prepend:seraph() {
    # Conditionally merge config files based on build variant (Android Bazel style)
    CONFIG_DIR="${WORKDIR}/wlan/qcacld-3.0/configs"

    # Check if this is a debug build (DISTRO contains "debug")
    if echo "${DISTRO}" | grep -q "debug"; then
        bbnote "Debug build detected - merging GKI and consolidate configs (Android Bazel style)"

        BASE_CONFIG="${CONFIG_DIR}/seraph_gki_peach-v2_defconfig"
        EXTRA_CONFIG="${CONFIG_DIR}/seraph_consolidate_peach-v2_defconfig"
        MERGED_CONFIG="${CONFIG_DIR}/seraph_debug_peach-v2_defconfig"

        # Simple concatenation like Android Bazel (Kconfig will handle duplicates)
        cat ${BASE_CONFIG} ${EXTRA_CONFIG} > ${MERGED_CONFIG}

        # Update config name for build
        export TARGET_WLAN_CHIP_CONFIG="seraph_debug_peach-v2"
        bbnote "Using merged config: ${TARGET_WLAN_CHIP_CONFIG}"
    else
        bbnote "Perf build detected - using GKI config only"
        export TARGET_WLAN_CHIP_CONFIG="seraph_gki_peach-v2"
    fi

    # Update BUILD_FLAGS with the selected config
    export BUILD_FLAGS="WLAN_ROOT=${S} CONFIG_QCA_CLD_WLAN_PROFILE=${TARGET_WLAN_CHIP_CONFIG} MODNAME=${WLAN_CHIP}_${TARGET_WLAN_CHIP}"
}

do_compile() {
    bbnote "==============================================================="
    bbnote "Building WLAN module with custom KCFLAGS"
    bbnote "==============================================================="
    #unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake CC="${KERNEL_CC}" ${BUILD_FLAGS} -C ${STAGING_KERNEL_BUILDDIR} \
       KBUILD_EXTRA_SYMBOLS="${STAGING_INCDIR}/kernel-module-soc-repo/Module.symvers ${STAGING_DIR_HOST}${base_libdir}/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers" \
       ${ADDITIONAL_CONFIGS} \
       KCFLAGS="-D__ANDROID_COMMON_KERNEL__ -I${STAGING_INCDIR}/soc-repo/include -I${STAGING_INCDIR}/soc-repo/include/linux" \
       QCA_WIFI_FTM_NL80211=y \
       M=${S} modules
}

do_install() {
    install -d ${S}/unstripped

    # Copy unstripped version with _v2 suffix
    cp -f ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko ${S}/unstripped/${WLAN_CHIP}_${TARGET_WLAN_CHIP}_v2.ko

    # Strip the module
    ${CLANG_BIN}/llvm-strip --strip-unneeded ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko

    # Rename to add _v2 suffix
    mv ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}_v2.ko

    # Install with new name
    install -m 0755 ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}_v2.ko -D ${D}/${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${WLAN_CHIP}_${TARGET_WLAN_CHIP}_v2.ko

    install -d ${D}/etc/modules-load.d
    install -m 0644 ${WORKDIR}/${BASEMACHINE}/wlan_load.conf ${D}/etc/modules-load.d/wlan_load.conf
    install -d ${FIRMWARE_PATH}
    install -m 0644 ${WORKDIR}/device/qcom/wlan/${BASEMACHINE}/WCNSS_qcom_cfg_${TARGET_WLAN_CHIP}_v2.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_module_signing[noexec] = "1"

# Deploying unstripped modules is done for crash analysis
do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/${WLAN_CHIP}_${TARGET_WLAN_CHIP}_v2.ko ${DEPLOYDIR}/kernel_modules
}

do_patch() {
     cd ${S}
     patch -p1 < ${WORKDIR}/qcacld-kbuild.patch
}

FILES:${PN} += "/etc/modules-load.d/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/*"

# Skip usrmerge QA check for kernel modules
INSANE_SKIP:${PN} += "usrmerge"

addtask do_deploy after do_install

addtask module_signing after do_package before do_package_write_ipk

# Preserve build artifacts for debugging
deltask do_rm_work
