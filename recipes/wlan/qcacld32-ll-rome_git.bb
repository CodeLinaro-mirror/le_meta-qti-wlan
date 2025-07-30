include qcacld32-ll.inc

DESCRIPTION = "Qualcomm Atheros WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

_MODNAME = "qca6574"
FW_PATH_NAME = "qca6174"
FILES:${PN} += "${nonarch_base_libdir}/firmware/wlan/*"
FILES:${PN} += "${nonarch_base_libdir}/firmware/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/*"
FILES:${PN} += "/usr/lib/firmware/wlan/*"
FILES:${PN} += "/usr/lib/firmware/*"
FILES:${PN} += "/usr/lib/firmware/${_MODNAME}"
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
SRC_URI:append = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6174.ini"
SRC_URI:append = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${_MODNAME}"
FIRMWARE_PATH:sa510m = "${D}/usr/lib/firmware/wlan/qca_cld/${_MODNAME}"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CLD_HL_SDIO_CORE=n CONFIG_CNSS_SDIO=n"
EXTRA_OEMAKE += "CONFIG_QCA_CLD_WLAN_PROFILE=qca6174"
EXTRA_OEMAKE += "DYNAMIC_SINGLE_CHIP=${_MODNAME}"
EXTRA_OEMAKE += "MODNAME=${_MODNAME}"

KERNEL_CC += "-w"

_WLAN_CFG_OVERRIDE_515 = "\
						CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n \
						CONFIG_WLAN_WBUFF=n \
						CONFIG_REMOVE_PKT_LOG=y \
						CONFIG_WDI_EVENT_ENABLE=n \
						CONFIG_NUM_IPA_IFACE=2 \
						CONFIG_ENABLE_SMMU_S1_TRANSLATION=y \
						CONFIG_FEATURE_IPA_PIPE_CHANGE_WDI1=y \
						CONFIG_MDM_PLATFORM=y \
						CONFIG_INTRA_BSS_FWD_OFFLOAD=y \
						CONFIG_WLAN_NAPI=n \
						CONFIG_SMMU_S1_UNMAP=y \
						CONFIG_FEATURE_DENYLIST_MGR=y \
						CONFIG_AUTO_PLATFORM=y \
						"
_WLAN_CFG_OVERRIDE_415 = "\
						CONFIG_MDM_PLATFORM=y \
						CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n \
						CONFIG_WLAN_WBUFF=n \
						CONFIG_REMOVE_PKT_LOG=y \
						CONFIG_WDI_EVENT_ENABLE=n \
						CONFIG_WLAN_NAPI=n \
						CONFIG_SMMU_S1_UNMAP=y \
						CONFIG_AUTO_PLATFORM=y \
                        "

_WLAN_CFG_OVERRIDE_410 = "\
						CONFIG_CNSS_OUT_OF_TREE=y \
						CONFIG_CNSS2=m \
						CONFIG_QMI=y \
						CONFIG_IPA3=n \
						CONFIG_IPA_OFFLOAD=n \
						CONFIG_CNSS_GENL=n \
						CONFIG_CNSS_UTILS=m \
						CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n \
						CONFIG_AUTO_PLATFORM=y \
                        "

_WLAN_CFG_OVERRIDE_525 = "\
						CONFIG_CNSS_OUT_OF_TREE=y \
						CONFIG_CNSS2=m \
						CONFIG_QMI=y \
						CONFIG_IPA3=y \
						CONFIG_IPA_OFFLOAD=y \
						CONFIG_IPA_WDI_UNIFIED_API=y \
						CONFIG_ENABLE_SMMU_S1_TRANSLATION=y \
						CONFIG_CNSS_GENL=n \
						CONFIG_CNSS_UTILS=m \
						CONFIG_WLAN_WBUFF=n \
						CONFIG_REMOVE_PKT_LOG=y \
						CONFIG_WDI_EVENT_ENABLE=n \
						CONFIG_MDM_PLATFORM=y \
						CONFIG_FEATURE_IPA_PIPE_CHANGE_WDI1=y \
						CONFIG_NUM_IPA_IFACE=2 \
						CONFIG_WLAN_CONV_SPECTRAL_ENABLE=n \
						CONFIG_ENABLE_VALLOC_REPLACE_MALLOC=y \
						CONFIG_INTRA_BSS_FWD_OFFLOAD=y \
						CONFIG_SMMU_S1_UNMAP=y \
						CONFIG_SHUTDOWN_WLAN_IN_SYSTEM_SUSPEND=y \
						CONFIG_AUTO_PLATFORM=y \
                        "

EXTRA_OEMAKE:append:sdxpoorwills = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_415}"
EXTRA_OEMAKE:append:sa515m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_515}"
EXTRA_OEMAKE:append:sa410m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_410}"
EXTRA_OEMAKE:append:sa525m = " WLAN_CFG_OVERRIDE=${_WLAN_CFG_OVERRIDE_525}"

WLAN_PLATFORM_PATH = "${WORKDIR}/recipe-sysroot/usr/include"
WLAN_KBUILD_EXTRA = "KBUILD_EXTRA_SYMBOLS=${WLAN_PLATFORM_PATH}/wlan-platform-dlkm/Module.symvers"
WLAN_PLATFORM_CFG = " KBUILD_EXTRA=${WLAN_KBUILD_EXTRA} WLAN_PLATFORM_INC=${WLAN_PLATFORM_PATH}"
EXTRA_OEMAKE:append = "${@bb.utils.contains('PREFERRED_VERSION_linux-msm', '5.15', '${WLAN_PLATFORM_CFG}', '', d)}"
DEPENDS:append:sa410m = "wlan-platform-dlkm"
DEPENDS:append:sa525m = "wlan-platform-dlkm"
DEPENDS:append:sa510m = "wlan-platform-dlkm"

LDFLAGS:aarch64 = "-O1 --hash-style=gnu --as-needed"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_ALLOW_OVERLAP_FILES.
SSTATE_ALLOW_OVERLAP_FILES += "${STAGING_DIR}/${MACHINE}${includedir}/qcacld/wlan_nlink_common.h"

inherit systemd
FILES:${PN}     += "${bindir}/init.qti.wlan_on.sh"
FILES:${PN}     += "${bindir}/init.qti.wlan_off.sh"

SRC_URI:append = " file://init_qti_wlan_auto.service"
SYSTEMD_SERVICE:${PN} = "init_qti_wlan_auto.service"

# disable wlan service on boot for sdxpoorwills-auto
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

SRC_URI:append = " file://init.qti.wlan_on.sh"
SRC_URI:append = " file://init.qti.wlan_off.sh"


EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

do_compile:prepend() {
    if ${@bb.utils.contains('PREFERRED_VERSION_linux-msm', '5.15', 'true', 'false', d)}; then
        CFG80211_FLAG="ccflags-y += -DCFG80211_SINGLE_NETDEV_MULTI_LINK_SUPPORT"
        sed -i -e "/$(CONFIG_QCA_CLD_WLAN_PROFILE)_defconfig$/i${CFG80211_FLAG}" ${S}/Kbuild
    fi
}
do_compile:prepend:sa410m() {
    CMD="echo 8 >/sys/class/net/wlan0/queues/tx-0/xps_cpus;echo 8 >/sys/class/net/wlan0/queues/rx-0/rps_cpus"
    sed -i -e "/Load wlanhost driver done/i${CMD}" ${WORKDIR}/init.qti.wlan_on.sh
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

do_install() {
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
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6174.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/wlan_mac.bin ${FIRMWARE_PATH}/wlan_mac.bin
    chmod -R 0664 ${FIRMWARE_PATH}/wlan_mac.bin
    install -d ${D}${bindir}
    install -D -m 0555 ${WORKDIR}/init.qti.wlan_on.sh ${D}${bindir}/init.qti.wlan_on.sh
    install -D -m 0555 ${WORKDIR}/init.qti.wlan_off.sh ${D}${bindir}/init.qti.wlan_off.sh
    if [ ${BASEMACHINE} != "sa510m" ]; then
        install -d ${D}/lib/firmware/${_MODNAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan30.b00 ${D}/lib/firmware/${_MODNAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan30.bin ${D}/lib/firmware/${_MODNAME}/
        mv ${D}/lib/firmware/${_MODNAME}/bdwlan30.bin ${D}/lib/firmware/${_MODNAME}/utfbd30.bin
        ln -sf /firmware/image/${FW_PATH_NAME}/qwlan30.bin ${D}/lib/firmware/${_MODNAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/utf30.bin ${D}/lib/firmware/${_MODNAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/otp30.bin ${D}/lib/firmware/${_MODNAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/data.msc ${D}/lib/firmware/${_MODNAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan30.b31 ${D}/lib/firmware/${_MODNAME}/
        mv ${D}/lib/firmware/${_MODNAME}/bdwlan30.b31 ${D}/lib/firmware/${_MODNAME}/utfbd30.b31
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan30.bin ${D}/lib/firmware/${_MODNAME}/
        ln -sf /firmware/image/${FW_PATH_NAME}/bdwlan30.b31 ${D}/lib/firmware/${_MODNAME}/
    fi
    # Install systemd service file
    if ${@bb.utils.contains('DISTRO_FEATURES','systemd','true','false',d)}; then
        install -m 0644 ${WORKDIR}/init_qti_wlan_auto.service -D ${D}${systemd_unitdir}/system/init_qti_wlan_auto.service
    fi
}

do_install:append:sa515m() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6174.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_install:append:sa415m() {
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6174.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
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
        if [ -f ${KERNEL_PREBUILT_PATH} ]; then
            WLAN_KO=${D}/${base_libdir}/modules/${KERNEL_VERSION}/extra
            export LD_LIBRARY_PATH=${KERNEL_PREBUILT_PATH}/dist
            ${KERNEL_PREBUILT_PATH}/dist/sign-file sha1 ${KERNEL_PREBUILT_PATH}/dist/signing_key.pem ${KKERNEL_PREBUILT_PATH}/dist/signing_key.x509 ${WLAN_KO}/${_MODNAME}.ko
        fi
    fi
}

addtask module_signing after do_package before do_package_qa do_package_write_ipk
