include qcacld32-ll.inc

DESCRIPTION = "Qualcomm Atheros WLAN CLD high latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

WLAN_MODULE_NAME = "wlan"

# The inherit of module.bbclass will automatically name module packages with
# kernel-module-" prefix as required by the oe-core build environment. Also it
# replaces '_' with '-' in the module name.
RPROVIDES:${PN} += "kernel-module-${@'${WLAN_MODULE_NAME}'.replace('_', '-')}-${KERNEL_VERSION}"
PROVIDES_NAME   = "kernel-module-${WLAN_MODULE_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r0"

#This DEPENDS is to serialize kernel module builds
DEPENDS = "rtsp-alg"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-2.0/"

S = "${UNPACKDIR}/wlan/qcacld-2.0/"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld"

EXTRA_OEMAKE += "CONFIG_CLD_LL_CORE=n CONFIG_CNSS_PCI=n MODNAME=${WLAN_MODULE_NAME} CHIP_NAME=${CHIP_NAME}"
EXTRA_OEMAKE += "CONFIG_CLD_HL_SDIO_CORE=y CONFIG_BUS_AUTO_SUSPEND=n"
EXTRA_OEMAKE += "CONFIG_STATICALLY_ADD_11P_CHANNELS=y CONFIG_SLUB_DEBUG_ON=n CONFIG_NON_QC_PLATFORM=n"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_ALLOW_OVERLAP_FILES.
SSTATE_ALLOW_OVERLAP_FILES += "${STAGING_DIR}/${MACHINE}${includedir}/qcacld/wlan_nlink_common.h"

do_install () {
    module_do_install

    # Enable OCB/DSRC tx per packet stats
    sed -i -e 's/^gOcbTxPerPktStatsEnable=0/gOcbTxPerPktStatsEnable=1/g' ${S}/firmware_bin/WCNSS_qcom_cfg.ini

    # Enable 802.11p (DSRC) standalone mode
    sed -i -e 's/^END/# OCB mode - 1=standalone\ngDot11PMode=1\n\nEND/g' ${S}/firmware_bin/WCNSS_qcom_cfg.ini

    # Set SoftAP Max Peer
    sed -i -e 's/^END/# Set SoftAP Max Peer\ngSoftApMaxPeers=10\n\nEND/g' ${S}/firmware_bin/WCNSS_qcom_cfg.ini

    install -d ${FIRMWARE_PATH}
    install -m 0644 ${S}/firmware_bin/WCNSS_cfg.dat ${FIRMWARE_PATH}/
    install -m 0644 ${S}/firmware_bin/WCNSS_qcom_cfg.ini ${FIRMWARE_PATH}/

    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S}/CORE/SVC/external/wlan_nlink_common.h ${D}${includedir}/qcacld/
}

do_module_signing() {
    if [ -f ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ]; then
        if [ ${BASEMACHINE} == "apq8017" ]; then
            ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PROVIDES_NAME}/lib/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_NAME}.ko
        elif [ ${BASEMACHINE} == "sdx20" ]; then
            ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PROVIDES_NAME}/lib/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_TARGET_NAME}.ko
        else
            ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PN}/lib/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_NAME}.ko
        fi
    fi
}

FILES:${PN}     += "lib/firmware/wlan/*"
FILES:${PN}     += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_NAME}.ko"

addtask module_signing after do_package before do_package_qa do_package_write_ipk
