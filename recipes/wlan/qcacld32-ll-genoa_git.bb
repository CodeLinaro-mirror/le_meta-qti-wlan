inherit autotools-brokensep module qperf

DESCRIPTION = "Qualcomm Atheros WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

_MODNAME = "qca6595"
FW_PATH_NAME = "qcn7605"
FILES:${PN}     += "lib/firmware/wlan/*"
FILES:${PN}     += "lib/firmware/*"
FILES:${PN}     += "lib/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko"
PROVIDES_NAME   = "kernel-module-${_MODNAME}"
RPROVIDES:${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"

# This DEPENDS is to serialize kernel module builds
DEPENDS = "rtsp-alg"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI:append:sdxprairie = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qcn7605.ini"
SRC_URI:append:sdxprairie = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"
SRC_URI:append:sa515m = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qcn7605.ini"
SRC_URI:append:sa515m = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"
SRC_URI:append:sa415m = " file://device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qcn7605.ini"
SRC_URI:append:sa415m = " file://device/qcom/wlan/sdx24_auto/wlan_mac.bin"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${_MODNAME}"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CLD_HL_SDIO_CORE=n CONFIG_CNSS_SDIO=n"
EXTRA_OEMAKE += "CONFIG_QCA_CLD_WLAN_PROFILE=genoa.pci.debug"
EXTRA_OEMAKE += "DYNAMIC_SINGLE_CHIP=${_MODNAME}"
EXTRA_OEMAKE += "MODNAME=${_MODNAME}"
EXTRA_OEMAKE:append:sa515m = " CONFIG_IPA_OFFLOAD=y"

_WLAN_CFG_OVERRIDE_515 = "\
						CONFIG_WLAN_NAPI=n \
						CONFIG_ENABLE_SMMU_S1_TRANSLATION=y \
						CONFIG_WDI2_IPA_OVER_GSI=y \
						CONFIG_WLAN_MAX_VDEVS=4 \
						CONFIG_SUPPORT_P2P_BY_ONE_INTF_WLAN=y \
						CONFIG_GET_DRIVER_MODE=y CONFIG_LTE_COEX=y \
						CONFIG_QCOM_LTE_COEX=y \
						CONFIG_FEATURE_COEX=y \
						CONFIG_QCACLD_FEATURE_BTC_CHAIN_MODE=y \
						CONFIG_QCACLD_FEATURE_COEX_CONFIG=y \
						CONFIG_WLAN_CFR_ENABLE=y \
						CONFIG_WLAN_CFR_ADRASTEA=y \
						CONFIG_WLAN_STREAMFS=y \
						"
_WLAN_CFG_OVERRIDE_415 = "\
						CONFIG_WLAN_NAPI=n \
						CONFIG_WLAN_MAX_VDEVS=4 \
						CONFIG_SUPPORT_P2P_BY_ONE_INTF_WLAN=y \
						CONFIG_IPA_OFFLOAD=y \
						CONFIG_WDI2_IPA_OVER_GSI=y \
						CONFIG_ENABLE_SMMU_S1_TRANSLATION=y \
						CONFIG_WDI2_IPA_HW_V4=y \
						CONFIG_MDM_PLATFORM=y \
						CONFIG_LTE_COEX=y \
						CONFIG_QCOM_LTE_COEX=y \
                        "
EXTRA_OEMAKE:append:sa515m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_515}"
EXTRA_OEMAKE:append:sdxprairie = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_515}"
EXTRA_OEMAKE:append:sa415m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_415}"

LDFLAGS:aarch64:automotive = "-O1 --hash-style=gnu --as-needed"

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
FILES:${PN}     += "usr/bin/init.qti.wlan_on.sh"
FILES:${PN}     += "usr/bin/init.qti.wlan_off.sh"

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
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan02.b03 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan03.b02 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan03.b03 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan03.b04 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan04.b01 ${D}/lib/firmware/${FW_PATH_NAME}/
    ln -sf /firmware/image/${FW_PATH_NAME}/genoaftm.bin ${D}/lib/firmware/${FW_PATH_NAME}/
    install -d ${D}${bindir}
    install -D -m 0755 ${WORKDIR}/init.qti.wlan_on.sh ${D}${bindir}/init.qti.wlan_on.sh
    install -D -m 0755 ${WORKDIR}/init.qti.wlan_off.sh ${D}${bindir}/init.qti.wlan_off.sh
    # Install systemd service file
    if ${@bb.utils.contains('DISTRO_FEATURES','systemd','true','false',d)}; then
        install -m 0644 ${WORKDIR}/init_qti_wlan_auto.service -D ${D}${systemd_unitdir}/system/init_qti_wlan_auto.service
    fi
}

do_install:append:sa515m() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qcn7605.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_install:append:sa415m() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qcn7605.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx24_auto/wlan_mac.bin ${FIRMWARE_PATH}/wlan_mac.bin
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

addtask module_signing after do_package before do_package_write_ipk
