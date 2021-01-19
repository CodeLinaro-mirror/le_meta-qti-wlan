inherit autotools-brokensep module qperf

DESCRIPTION = "Qualcomm Atheros WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

_MODNAME = "qca6696"
FW_PATH_NAME = "qca6390"
FILES_${PN}     += "lib/firmware/wlan/*"
FILES_${PN}     += "lib/firmware/*"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko"
PROVIDES_NAME   = "kernel-module-${_MODNAME}"
RPROVIDES_${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"

# This DEPENDS is to serialize kernel module builds
DEPENDS = "rtsp-alg"
DEPENDS_remove_automotive = "rtsp-alg"
DEPENDS_remove_auto = "rtsp-alg"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI_append_automotive = " file://device/qcom/wlan/msm_auto/WCNSS_qcom_cfg_qca6390.ini"
SRC_URI_append_sdxprairie = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6390.ini"
SRC_URI_append_sdxprairie = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"
SRC_URI_append_sa415m = " file://device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qca6390.ini"
SRC_URI_append_sa415m = " file://device/qcom/wlan/sdx24_auto/wlan_mac.bin"

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
EXTRA_OEMAKE_append_sdxprairie = " CONFIG_ENABLE_IPA=y"
EXTRA_OEMAKE_append_sa8155 = " CONFIG_ENABLE_IPA=n"

#Enable DFS channel in STA_AP_MODE for sdxprairie platform
EXTRA_OEMAKE_append_sdxprairie = " WLAN_CFG_OVERRIDE="CONFIG_FEATURE_FORCE_WAKE=y CONFIG_FEATURE_HAL_DELAYED_REG_WRITE=y CONFIG_FEATURE_WLAN_STA_AP_MODE_DFS_DISABLE=n CONFIG_SUPPORT_P2P_BY_ONE_INTF_WLAN=y CONFIG_DCS=n CONFIG_WLAN_FEATURE_MIB_STATS=n CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n CONFIG_FEATURE_MEMDUMP_ENABLE=n CONFIG_FEATURE_UNIT_TEST_SUSPEND=n CONFIG_WLAN_WBUFF=n CONFIG_TSO_DEBUG_LOG_ENABLE=n CONFIG_WLAN_FEATURE_P2P_DEBUG=n CONFIG_DESC_DUP_DETECT_DEBUG=n CONFIG_DEBUG_RX_RING_BUFFER=n CONFIG_FOURTH_CONNECTION=n CONFIG_FOURTH_CONNECTION_AUTO=n CONFIG_REMOVE_PKT_LOG=y CONFIG_WDI_EVENT_ENABLE=n CONFIG_SMMU_S1_UNMAP=y""
EXTRA_OEMAKE_append_sa415m = " WLAN_CFG_OVERRIDE="CONFIG_FEATURE_FORCE_WAKE=y CONFIG_FEATURE_HAL_DELAYED_REG_WRITE=y CONFIG_FEATURE_WLAN_STA_AP_MODE_DFS_DISABLE=n CONFIG_SUPPORT_P2P_BY_ONE_INTF_WLAN=y CONFIG_FEATURE_MONITOR_MODE_SUPPORT=n CONFIG_DCS=n CONFIG_WLAN_FEATURE_MIB_STATS=n CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n CONFIG_FEATURE_MEMDUMP_ENABLE=n CONFIG_FEATURE_UNIT_TEST_SUSPEND=n CONFIG_WLAN_WBUFF=n CONFIG_TSO_DEBUG_LOG_ENABLE=n CONFIG_WLAN_FEATURE_P2P_DEBUG=n CONFIG_DESC_DUP_DETECT_DEBUG=n CONFIG_DEBUG_RX_RING_BUFFER=n CONFIG_FOURTH_CONNECTION=n CONFIG_FOURTH_CONNECTION_AUTO=n CONFIG_REMOVE_PKT_LOG=y CONFIG_WDI_EVENT_ENABLE=n""

LDFLAGS_aarch64_automotive = "-O1 --hash-style=gnu --as-needed"
LDFLAGS_aarch64_auto = "-O1 --hash-style=gnu --as-needed"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_DUPWHITELIST.
SSTATE_DUPWHITELIST += "${STAGING_DIR}/${MACHINE}${includedir}/qcacld/wlan_nlink_common.h"

inherit systemd
SRC_URI_append_automotive = " file://init_qti_wlan_auto.service"
SYSTEMD_SERVICE_${PN}_automotive = "init_qti_wlan_auto.service"
SYSTEMD_AUTO_ENABLE_${PN}_automotive = "enable"
SRC_URI_append_auto = " file://init_qti_wlan_auto.service"
SYSTEMD_SERVICE_${PN}_auto = "init_qti_wlan_auto.service"
SYSTEMD_AUTO_ENABLE_${PN}_auto = "disable"

SRC_URI_append_automotive = " file://init.qti.wlan_on.sh"
SRC_URI_append_automotive = " file://init.qti.wlan_off.sh"
SRC_URI_append_auto = " file://init.qti.wlan_on.sh"
SRC_URI_append_auto = " file://init.qti.wlan_off.sh"
FILES_${PN}     += "usr/bin/init.qti.wlan_on.sh"
FILES_${PN}     += "usr/bin/init.qti.wlan_off.sh"

do_compile_prepend_automotive() {
    #Add gnu99 for compiler compatible issues
    sed -i '$a\ccflags-y += -std=gnu99' ${S}/Kbuild
    #In yocto system, get build tag by 'git log' in wlan src dir instead of 'git reflog' in work dir
    sed -i -e '/^ifeq ($(CONFIG_BUILD_TAG), y)/,/^endif/{/^ifeq ($(CONFIG_BUILD_TAG), y)/!{/^endif/!d}}' ${S}/Kbuild
    sed -i -e '/^ifeq ($(CONFIG_BUILD_TAG), y)/a\
WLAN_ROOT_LV = ${WORKSPACE}/wlan/qcacld-3.0\
WLAN_CMN_LV = ${WORKSPACE}/wlan/qca-wifi-host-cmn\
CLD_IDS = $(shell cd "$(WLAN_ROOT_LV)" && git log -1 | sed -nE '\''s/^\\s*Change-Id: (I[0-f]{10})[0-f]{30}\\s*\$\$/\\1/p'\'')\
CMN_IDS = $(shell cd "$(WLAN_CMN_LV)" && git log -1 | sed -nE '\''s/^\\s*Change-Id: (I[0-f]{10})[0-f]{30}\\s*\$\$/\\1/p'\'')\
TIMESTAMP = $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')\
BUILD_TAG = "$(TIMESTAMP); cld:$(CLD_IDS); cmn:$(CMN_IDS);"\
CFLAGS_wlan_hdd_main.o += -DBUILD_TAG=\\"$(BUILD_TAG)\\"' ${S}/Kbuild
}

do_compile_prepend_auto() {
    #Add gnu99 for compiler compatible issues
    sed -i '$a\ccflags-y += -std=gnu99' ${S}/Kbuild
    #In yocto system, get build tag by 'git log' in wlan src dir instead of 'git reflog' in work dir
    sed -i -e '/^ifeq ($(CONFIG_BUILD_TAG), y)/,/^endif/{/^ifeq ($(CONFIG_BUILD_TAG), y)/!{/^endif/!d}}' ${S}/Kbuild
    sed -i -e '/^ifeq ($(CONFIG_BUILD_TAG), y)/a\
    WLAN_ROOT_LV = ${WORKSPACE}/wlan/qcacld-3.0\
    WLAN_CMN_LV = ${WORKSPACE}/wlan/qca-wifi-host-cmn\
    CLD_IDS = $(shell cd "$(WLAN_ROOT_LV)" && git log -1 | sed -nE '\''s/^\\s*Change-Id: (I[0-f]{10})[0-f]{30}\\s*\$\$/\\1/p'\'')\
    CMN_IDS = $(shell cd "$(WLAN_CMN_LV)" && git log -1 | sed -nE '\''s/^\\s*Change-Id: (I[0-f]{10})[0-f]{30}\\s*\$\$/\\1/p'\'')\
    TIMESTAMP = $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')\
    BUILD_TAG = "$(TIMESTAMP); cld:$(CLD_IDS); cmn:$(CMN_IDS);"\
    CFLAGS_wlan_hdd_main.o += -DBUILD_TAG=\\"$(BUILD_TAG)\\"' ${S}/Kbuild
}

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
do_install_append_automotive() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/msm_auto/WCNSS_qcom_cfg_qca6390.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/msm_auto/wlan_mac.bin ${FIRMWARE_PATH}/wlan_mac.bin
    install -d ${D}${bindir}
    install -D -m 0755 ${WORKDIR}/init.qti.wlan_on.sh ${D}${bindir}/init.qti.wlan_on.sh
    install -D -m 0755 ${WORKDIR}/init.qti.wlan_off.sh ${D}${bindir}/init.qti.wlan_off.sh
    # Install systemd service file
    if ${@bb.utils.contains('DISTRO_FEATURES','systemd','true','false',d)}; then
        install -m 0644 ${WORKDIR}/init_qti_wlan_auto.service -D ${D}${systemd_unitdir}/system/init_qti_wlan_auto.service
    fi
}

do_install_append_auto() {
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

do_install_append_sa515m_auto() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6390.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chown -RH root:1001 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_install_append_sa415m_auto() {
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

addtask module_signing after do_package before do_package_write_ipk
