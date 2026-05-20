include qcacld32-ll.inc

DESCRIPTION = "Qualcomm Atheros WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

_MODNAME = "qca6696"
FW_PATH_NAME = "qca6390"
FILES:${PN}     += "${nonarch_base_libdir}/firmware/wlan/*"
FILES:${PN}     += "${nonarch_base_libdir}/firmware/*"
FILES:${PN}     += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko"
PROVIDES_NAME   = "kernel-module-${_MODNAME}"
RPROVIDES:${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"


FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI:append:sdxprairie = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6390.ini"
SRC_URI:append:sdxprairie = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"
SRC_URI:append:sa515m = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6390.ini"
SRC_URI:append:sa515m = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"
SRC_URI:append:sa415m = " file://device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qca6390.ini"
SRC_URI:append:sa415m = " file://device/qcom/wlan/sdx24_auto/wlan_mac.bin"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${_MODNAME}"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CLD_HL_SDIO_CORE=n CONFIG_CNSS_SDIO=n"
EXTRA_OEMAKE += "CONFIG_QCA_CLD_WLAN_PROFILE=qca6390"
EXTRA_OEMAKE += "DYNAMIC_SINGLE_CHIP=${_MODNAME}"
EXTRA_OEMAKE += "MODNAME=${_MODNAME}"

#Enable/Disable IPA by MACHINE name
EXTRA_OEMAKE:append:sdxprairie = " CONFIG_ENABLE_IPA=y"
EXTRA_OEMAKE:append:sa515m = " CONFIG_ENABLE_IPA=y CONFIG_DEVICE_FORCE_WAKE_ENABLE=y CONFIG_HIF_REG_WINDOW_SUPPORT=y"

#Enable DFS channel in STA_AP_MODE for sdxprairie platform
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
						CONFIG_WLAN_NAPI=n \
						CONFIG_AUTO_PLATFORM=y \
						"
_WLAN_CFG_OVERRIDE_415 = "\
						CONFIG_FEATURE_FORCE_WAKE=y \
						CONFIG_FEATURE_HAL_DELAYED_REG_WRITE=y \
						CONFIG_FEATURE_WLAN_STA_AP_MODE_DFS_DISABLE=n \
						CONFIG_SUPPORT_P2P_BY_ONE_INTF_WLAN=y \
						CONFIG_FEATURE_MONITOR_MODE_SUPPORT=n \
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
						CONFIG_WLAN_NAPI=n \
						CONFIG_AUTO_PLATFORM=y \
						"

EXTRA_OEMAKE:append:sa515m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_515}"
EXTRA_OEMAKE:append:sdxprairie = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_515}"
EXTRA_OEMAKE:append:sa415m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_415}"

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

do_install () {
    module_do_install

    install -d ${FIRMWARE_PATH}
    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/

    #copying wlan.ko to STAGING_DIR_TARGET
    WLAN_KO=${@oe.utils.conditional('PERF_BUILD', '1', '${STAGING_DIR_TARGET}-perf', '${STAGING_DIR_TARGET}', d)}
    install -d ${WLAN_KO}/wlan
    install -m 0644 ${S}/${_MODNAME}.ko ${WLAN_KO}/wlan/
}

do_install:append() {
    install -d ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/amss.bin ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/amss20.bin ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan02.e01 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan02.e02 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan02.e03 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan.elf ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/m3.bin ${D}/lib/firmware/${FW_PATH_NAME}/
    install -d ${D}${bindir}
    install -D -m 0755 ${WORKDIR}/init.qti.wlan_on.sh ${D}${bindir}/init.qti.wlan_on.sh
    install -D -m 0755 ${WORKDIR}/init.qti.wlan_off.sh ${D}${bindir}/init.qti.wlan_off.sh
    # Install systemd service file
    if ${@bb.utils.contains('DISTRO_FEATURES','systemd','true','false',d)}; then
        install -m 0644 ${WORKDIR}/init_qti_wlan_auto.service -D ${D}${systemd_unitdir}/system/init_qti_wlan_auto.service
    fi
}

do_install:append:sa515m() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6390.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_install:append:sa415m() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qca6390.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chown -RH root:1001 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx24_auto/wlan_mac.bin ${FIRMWARE_PATH}/wlan_mac.bin
    chown -RH root:1001 ${FIRMWARE_PATH}/wlan_mac.bin
    chmod -R 0664 ${FIRMWARE_PATH}/wlan_mac.bin
}

do_module_signing() {
    if [ -f ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ]; then
        bbnote "Signing ${PN} module"
        ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PROVIDES_NAME}/lib/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko
    elif [ -f ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ]; then
        ${STAGING_KERNEL_BUILDDIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.x509 ${PKGDEST}/${PN}/lib/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko
    else
        bbnote "${PN} module is not being signed"
    fi
}

addtask module_signing after do_package before do_package_qa do_package_write_ipk
