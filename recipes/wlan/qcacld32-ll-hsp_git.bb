include qcacld32-ll.inc

SUMMARY = "Qualcomm Technologies, Inc. WLAN Driver"
DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver for the first WLAN chip.\
               It is a kernel extra module, which loaded by qca6696-module-load.service \
               once the system bootup. And this WLAN host driver module name is qca6490.ko,\
               it create two interface by defaults, one is wlan0 and the other is wlan1. \
               Application can use the wireless interfaces as STA or AP mode in need. \
               Usually, it bind to pcie0 slot by default if it loaded first. \"
HOMEPAGE = "https://git.codelinaro.org/"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

PR = "r8"
_MODNAME = "qca6490"
FW_PATH_NAME = "qca6490"
FILES:${PN}     += "${nonarch_base_libdir}/firmware/wlan/*"
FILES:${PN}     += "${nonarch_base_libdir}/firmware/*"
FILES:${PN}     += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko"
FILES:${PN}     += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/"
FILES:${PN} += "/usr/lib/*"
FILES:${PN} += "/usr/lib/firmware/*"
FILES:${PN} += "/usr/lib/firmware/wlan/*"
FILES:${PN} += "/usr/lib/firmware/wlan/qca_cld/*"
FILES:${PN} += "/usr/lib/firmware/wlan/qca_cld/${_MODNAME}"
FILES:${PN} += "/usr/bin/*"
PROVIDES_NAME   = "kernel-module-${_MODNAME}"
RPROVIDES:${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
do_configure[noexec] = "1"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn"
S = "${WORKDIR}/wlan/qcacld-3.0"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${_MODNAME}"
FIRMWARE_PATH:sa510m = "${D}/usr/lib/firmware/wlan/qca_cld/${_MODNAME}"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE:append = " CONFIG_CLD_HL_SDIO_CORE=n \
                       CONFIG_CNSS_SDIO=n \
                       CONFIG_QCA_CLD_WLAN_PROFILE=qca6490 \
                       DYNAMIC_SINGLE_CHIP=${_MODNAME} \
                       MODNAME=${_MODNAME} \
                       "

KERNEL_CC += "-Wno-error=misleading-indentation"
KERNEL_CC += "-w"

#Enable/Disable IPA by MACHINE name
EXTRA_OEMAKE:append:sa515m = " CONFIG_ENABLE_IPA=n"

_WLAN_CFG_OVERRIDE_515 = "\
						CONFIG_FEATURE_FORCE_WAKE=y \
						CONFIG_FEATURE_HAL_DELAYED_REG_WRITE=y \
						CONFIG_FEATURE_WLAN_STA_AP_MODE_DFS_DISABLE=n \
						CONFIG_SUPPORT_P2P_BY_ONE_INTF_WLAN=y \
						CONFIG_DCS=n \
						CONFIG_WLAN_FEATURE_MIB_STATS=n \
						CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n \
						CONFIG_FEATURE_MEMDUMP_ENABLE=n \
						CONFIG_FEATURE_UNIT_TEST_SUSPEND=n \
						CONFIG_WLAN_WBUFF=n \
						CONFIG_TSO_DEBUG_LOG_ENABLE=n \
						CONFIG_WLAN_FEATURE_P2P_DEBUG=n \
						CONFIG_DESC_DUP_DETECT_DEBUG=n \
						CONFIG_DEBUG_RX_RING_BUFFER=n \
						CONFIG_FOURTH_CONNECTION=n \
						CONFIG_FOURTH_CONNECTION_AUTO=n \
						CONFIG_REMOVE_PKT_LOG=y \
						CONFIG_WDI_EVENT_ENABLE=n \
						CONFIG_SMMU_S1_UNMAP=y \
						CONFIG_REO_DESC_DEFER_FREE=y \
						CONFIG_FEATURE_COEX=y \
						CONFIG_QCACLD_FEATURE_BTC_CHAIN_MODE=y \
						CONFIG_QCACLD_FEATURE_COEX_CONFIG=y \
						CONFIG_DIRECT_BUF_RX_ENABLE=y \
						CONFIG_WMI_DBR_SUPPORT=y \
						CONFIG_QCOM_ESE=y \
						CONFIG_RX_FISA=n \
						CONFIG_WLAN_BCN_RECV_FEATURE=n \
						CONFIG_SAP_AVOID_ACS_FREQ_LIST=n \
						CONFIG_SAR_SAFETY_FEATURE=n \
						CONFIG_FEATURE_INTEROP_ISSUES_AP=n \
						CONFIG_FEATURE_CLUB_LL_STATS_AND_GET_STATION=n \
						CONFIG_INTERFACE_MGR=n \
						CONFIG_FEATURE_MSCS=n \
						CONFIG_ADAPTIVE_11R=n \
						CONFIG_CM_ROAM_OFFLOAD=n \
						CONFIG_ANI_LEVEL_REQUEST=n \
						CONFIG_WLAN_HANG_EVENT=n \
						CONFIG_FEATURE_VDEV_OPS_WAKELOCK=n \
						CONFIG_QCACLD_RX_DESC_MULTI_PAGE_ALLOC=n \
						CONFIG_RX_HASH_DEBUG=n \
						CONFIG_DP_MEM_PRE_ALLOC=n \
						CONFIG_MAX_ALLOC_PAGE_SIZE=n \
						CONFIG_UNIT_TEST=n \
						CONFIG_DSC_DEBUG=n \
						CONFIG_LEAK_DETECTION=n \
						CONFIG_TALLOC_DEBUG=n \
						CONFIG_HAL_DEBUG=n \
						CONFIG_HIF_DEBUG=n \
						CONFIG_QDF_TEST=n \
						CONFIG_HIF_REG_WINDOW_SUPPORT=y \
						CONFIG_DEVICE_FORCE_WAKE_ENABLE=y \
						CONFIG_HIF_CE_DEBUG_DATA_BUF=n  \
						CONFIG_BAND_6GHZ=y \
						CONFIG_IPA_WDI3_TX_TWO_PIPES=n \
						CONFIG_HANDLE_RX_REROUTE_ERR=n \
						CONFIG_WLAN_FEATURE_P2P_P2P_STA=n \
						CONFIG_WLAN_FEATURE_DP_RX_RING_HISTORY=n \
						CONFIG_WLAN_FEATURE_DP_TX_DESC_HISTORY=n \
						CONFIG_REO_QDESC_HISTORY=n \
						CONFIG_DP_TX_HW_DESC_HISTORY=n \
						CONFIG_WLAN_FEATURE_DP_EVENT_HISTORY=n \
						CONFIG_RX_DESC_DEBUG_CHECK=n \
						CONFIG_QCACLD_WLAN_CONNECTIVITY_LOGGING=n \
						CONFIG_DP_TX_TRACKING=n \
						CONFIG_WLAN_DEBUG_LINK_VOTE=n \
						CONFIG_ENABLE_VALLOC_REPLACE_MALLOC=y \
						CONFIG_WLAN_NAPI=n \
						CONFIG_AUTO_PLATFORM=y \
						CONFIG_QDF_MAX_NO_OF_SAP_MODE=3 \
						"

_WLAN_CFG_OVERRIDE_525 = "\
						CONFIG_FEATURE_WLAN_STA_AP_MODE_DFS_DISABLE=n \
						CONFIG_SUPPORT_P2P_BY_ONE_INTF_WLAN=y \
						CONFIG_DCS=n \
						CONFIG_WLAN_FEATURE_MIB_STATS=n \
						CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n \
						CONFIG_FEATURE_MEMDUMP_ENABLE=n \
						CONFIG_FEATURE_UNIT_TEST_SUSPEND=n \
						CONFIG_WLAN_WBUFF=n \
						CONFIG_TSO_DEBUG_LOG_ENABLE=n \
						CONFIG_WLAN_FEATURE_P2P_DEBUG=n \
						CONFIG_DESC_DUP_DETECT_DEBUG=n \
						CONFIG_DEBUG_RX_RING_BUFFER=n \
						CONFIG_FOURTH_CONNECTION=n \
						CONFIG_FOURTH_CONNECTION_AUTO=n \
						CONFIG_REMOVE_PKT_LOG=y \
						CONFIG_WDI_EVENT_ENABLE=n \
						CONFIG_SMMU_S1_UNMAP=y \
						CONFIG_REO_DESC_DEFER_FREE=y \
						CONFIG_FEATURE_COEX=y \
						CONFIG_QCACLD_FEATURE_BTC_CHAIN_MODE=y \
						CONFIG_QCACLD_FEATURE_COEX_CONFIG=y \
						CONFIG_DIRECT_BUF_RX_ENABLE=y \
						CONFIG_WMI_DBR_SUPPORT=y \
						CONFIG_QCOM_ESE=y \
						CONFIG_RX_FISA=n \
						CONFIG_WLAN_BCN_RECV_FEATURE=n \
						CONFIG_SAP_AVOID_ACS_FREQ_LIST=n \
						CONFIG_SAR_SAFETY_FEATURE=n \
						CONFIG_FEATURE_INTEROP_ISSUES_AP=n \
						CONFIG_FEATURE_CLUB_LL_STATS_AND_GET_STATION=n \
						CONFIG_INTERFACE_MGR=n \
						CONFIG_FEATURE_MSCS=n \
						CONFIG_ADAPTIVE_11R=n \
						CONFIG_CM_ROAM_OFFLOAD=n \
						CONFIG_ANI_LEVEL_REQUEST=n \
						CONFIG_WLAN_HANG_EVENT=n \
						CONFIG_FEATURE_VDEV_OPS_WAKELOCK=n \
						CONFIG_QCACLD_RX_DESC_MULTI_PAGE_ALLOC=n \
						CONFIG_RX_HASH_DEBUG=n \
						CONFIG_DP_MEM_PRE_ALLOC=n \
						CONFIG_MAX_ALLOC_PAGE_SIZE=n \
						CONFIG_UNIT_TEST=n \
						CONFIG_DSC_DEBUG=n \
						CONFIG_LEAK_DETECTION=n \
						CONFIG_TALLOC_DEBUG=n \
						CONFIG_HAL_DEBUG=n \
						CONFIG_HIF_DEBUG=n \
						CONFIG_QDF_TEST=n \
						CONFIG_HIF_REG_WINDOW_SUPPORT=y \
						CONFIG_DEVICE_FORCE_WAKE_ENABLE=y \
						CONFIG_HIF_CE_DEBUG_DATA_BUF=n  \
						CONFIG_BAND_6GHZ=y \
						CONFIG_IPA_WDI3_TX_TWO_PIPES=n \
						CONFIG_HANDLE_RX_REROUTE_ERR=n \
						CONFIG_WLAN_FEATURE_P2P_P2P_STA=n \
						CONFIG_WLAN_FEATURE_DP_RX_RING_HISTORY=n \
						CONFIG_WLAN_FEATURE_DP_TX_DESC_HISTORY=n \
						CONFIG_REO_QDESC_HISTORY=n \
						CONFIG_DP_TX_HW_DESC_HISTORY=n \
						CONFIG_WLAN_FEATURE_DP_EVENT_HISTORY=n \
						CONFIG_RX_DESC_DEBUG_CHECK=n \
						CONFIG_QCACLD_WLAN_CONNECTIVITY_LOGGING=n \
						CONFIG_DP_TX_TRACKING=n \
						CONFIG_WLAN_DEBUG_LINK_VOTE=n \
						CONFIG_QCOM_LTE_COEX=y \
						CONFIG_CNSS_OUT_OF_TREE=y \
						CONFIG_CNSS2=m \
						CONFIG_QMI=y \
						CONFIG_IPA3=y \
						CONFIG_IPA_OFFLOAD=y \
						CONFIG_ENABLE_SMMU_S1_TRANSLATION=y \
						CONFIG_IPA_WDI_UNIFIED_API=y  \
						CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n \
						CONFIG_WLAN_CFR_ENABLE=n \
						CONFIG_WLAN_CFR_ADRASTEA=n \
						CONFIG_ENABLE_VALLOC_REPLACE_MALLOC=y \
						CONFIG_MDM_PLATFORM=y \
						CONFIG_SHUTDOWN_WLAN_IN_SYSTEM_SUSPEND=y \
						CONFIG_AUTO_PLATFORM=y \
						CONFIG_QDF_MAX_NO_OF_SAP_MODE=3 \
						CONFIG_IPA_P2P_SUPPORT=y \
						"

EXTRA_OEMAKE:append:sa515m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_515}"
EXTRA_OEMAKE:append:sa525m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_525}"

WLAN_PLATFORM_PATH = "${WORKDIR}/recipe-sysroot/usr/include"
WLAN_KBUILD_EXTRA = "KBUILD_EXTRA_SYMBOLS=${WLAN_PLATFORM_PATH}/wlan-platform-dlkm/Module.symvers"
WLAN_PLATFORM_CFG = " KBUILD_EXTRA=${WLAN_KBUILD_EXTRA} WLAN_PLATFORM_INC=${WLAN_PLATFORM_PATH}"
EXTRA_OEMAKE:append = "${@bb.utils.contains('PREFERRED_VERSION_linux-msm', '5.15', '${WLAN_PLATFORM_CFG}', '', d)}"
DEPENDS:append:sa525m = "wlan-platform-dlkm"
DEPENDS:append:sa510m = "wlan-platform-dlkm"

LDFLAGS:aarch64 = "-O1 --hash-style=gnu --as-needed"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_ALLOW_OVERLAP_FILES.
SSTATE_ALLOW_OVERLAP_FILES += "${STAGING_DIR}/${MACHINE}${includedir}/qcacld/wlan_nlink_common.h"

inherit systemd
SRC_URI:append = " file://init_qti_wlan_auto.service"
SYSTEMD_SERVICE:${PN} = "init_qti_wlan_auto.service"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

SRC_URI:append = " file://init.qti.wlan_on.sh"
SRC_URI:append = " file://init.qti.wlan_off.sh"
FILES:${PN}     += "${bindir}/init.qti.wlan_on.sh"
FILES:${PN}     += "${bindir}/init.qti.wlan_off.sh"

EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

do_compile:prepend() {
    if ${@bb.utils.contains('PREFERRED_VERSION_linux-msm', '5.15', 'true', 'false', d)}; then
        CFG80211_FLAG="ccflags-y += -DCFG80211_SINGLE_NETDEV_MULTI_LINK_SUPPORT"
        sed -i -e "/$(CONFIG_QCA_CLD_WLAN_PROFILE)_defconfig$/i${CFG80211_FLAG}" ${S}/Kbuild
    fi
}

do_compile:sa510m() {
    variant="${@bb.utils.contains('DEBUG_BUILD','1', "debug", "perf", d)}"
    cd ${KERNEL_PLATFORM_PATH}
    ln -sf ../../wlan
    ENABLE_DDK_BUILD=true \
    TARGET_BOARD_PLATFORM=sa510m \
    BUILD_CONFIG=${KERNEL_BUILD_CONFIG} \
    EXT_MODULES=${EXT_MODULES} \
    ROOTDIR=${WORKDIR}/ \
    MODULE_OUT=${S} \
    OUT_DIR=${KERNEL_PREBUILT_PATH} \
    VARIANT=${variant}_defconfig \
    KERNEL_UAPI_HEADERS_DIR=${STAGING_KERNEL_BUILDDIR} \
    SUBTARGET_REGEX=${_MODNAME}_modules \
    ./build/build_module.sh
}

do_install () {
    if [ ${BASEMACHINE} != "sa510m" ]; then
        module_do_install
        #copying wlan.ko to STAGING_DIR_TARGET
        WLAN_KO=${@oe.utils.conditional('PERF_BUILD', '1', '${STAGING_DIR_TARGET}-perf', '${STAGING_DIR_TARGET}', d)}
        install -d ${WLAN_KO}/wlan
        install -m 0644 ${S}/${_MODNAME}.ko ${WLAN_KO}/wlan/
    else
        WLAN_KO=${D}/${base_libdir}/modules/${KERNEL_VERSION}/extra
        install -d ${WLAN_KO}
        install -m 0644 ${S}/${_MODNAME}.ko ${WLAN_KO}/${_MODNAME}.ko
    fi

    install -d ${FIRMWARE_PATH}
    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/
}

do_install:append() {
    if [ ${BASEMACHINE} != "sa510m" ]; then
        install -d ${D}/lib/firmware/${FW_PATH_NAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/amss.bin ${D}/lib/firmware/${FW_PATH_NAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/amss20.bin ${D}/lib/firmware/${FW_PATH_NAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan02.e01 ${D}/lib/firmware/${FW_PATH_NAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan02.e02 ${D}/lib/firmware/${FW_PATH_NAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan02.e03 ${D}/lib/firmware/${FW_PATH_NAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan.elf ${D}/lib/firmware/${FW_PATH_NAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/m3.bin ${D}/lib/firmware/${FW_PATH_NAME}/
    fi
    install -d ${D}${bindir}
    install -D -m 0555 ${WORKDIR}/init.qti.wlan_on.sh ${D}${bindir}/init.qti.wlan_on.sh
    install -D -m 0555 ${WORKDIR}/init.qti.wlan_off.sh ${D}${bindir}/init.qti.wlan_off.sh
    # Install systemd service file
    if ${@bb.utils.contains('DISTRO_FEATURES','systemd','true','false',d)}; then
        install -m 0644 ${WORKDIR}/init_qti_wlan_auto.service -D ${D}${systemd_unitdir}/system/init_qti_wlan_auto.service
    fi
}

do_module_signing() {
    if [ ${BASEMACHINE} != "sa510m" ]; then
        if [ -f ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ]; then
            bbnote "Signing ${PN} module"
            ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PROVIDES_NAME}/lib/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko
        elif [ -f ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ]; then
            bbnote "Signing ${PN} module with pem"
            ${STAGING_KERNEL_BUILDDIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.x509 ${PKGDEST}/${PN}/lib/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko
        else
            bbnote "${PN} module is not being signed"
        fi
    else
        if [ -f ${KERNEL_PREBUILT_PATH}/dist/signing_key.pem ]; then
            WLAN_KO=${D}/${base_libdir}/modules/${KERNEL_VERSION}/extra
            export LD_LIBRARY_PATH=${KERNEL_PREBUILT_PATH}/dist
            ${KERNEL_PREBUILT_PATH}/dist/sign-file sha1 ${KERNEL_PREBUILT_PATH}/dist/signing_key.pem ${KERNEL_PREBUILT_PATH}/dist/signing_key.x509 ${WLAN_KO}/${_MODNAME}.ko
        fi
    fi
}

addtask module_signing after do_package before do_package_qa do_package_write_ipk
