inherit autotools-brokensep module qperf

# if is TARGET_KERNEL_ARCH is set inherit qtikernel-arch to compile for that arch.
inherit ${@bb.utils.contains('TARGET_KERNEL_ARCH', 'aarch64', 'qtikernel-arch', '', d)}

DESCRIPTION = "Qualcomm Atheros WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

FILES_${PN}     += "lib/firmware/wlan/*"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/wlan.ko"
PROVIDES_NAME   = "kernel-module-wlan"
RPROVIDES_${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"

# This DEPENDS is to serialize kernel module builds
DEPENDS = "rtsp-alg"
DEPENDS_append_sdmsteppe = " virtual/kernel"
DEPENDS_remove_sdmsteppe = "rtsp-alg"

QCACMN_REV = "LE.UM.4.2.1.r1-09300-QCS404.0"
QCAAPI_REV = "LE.UM.4.2.1.r1-08200-QCS404.0"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/fw-api/snapshot/${QCAAPI_REV}.tar.gz;subdir=wlan;name=api"
SRC_URI += "https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/qca-wifi-host-cmn/snapshot/${QCACMN_REV}.tar.gz;subdir=wlan;name=cmn"

SRC_URI[api.md5sum] = "76223e548dd9c20c223da7778cfca6f8"
SRC_URI[api.sha256sum] = "af5ffdd457ee68dd5d70d053faf0b57fe15aec44ac7a0306d6efab3506ac1983"
SRC_URI[cmn.md5sum] = "9962a3cd9d4f3f6cc31fd365fadbf942"
SRC_URI[cmn.sha256sum] = "4f4142a74cf78ba5dd1919146df4f0a5c0335b9f197a7df4c6736a7f38bf3d17"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CNSS=n CONFIG_CLD_HL_SDIO_CORE=n CONFIG_CNSS_SDIO=n"

WLAN_CONFIG = "${@bb.utils.contains('DISTRO_FEATURES', 'wlan-perf', 'qcs40x.snoc.perf', 'default', d)}"

# Force qcs40x use: ./qcacld-3.0/configs/qcs40x.snoc.perf_defconfig
python __anonymous () {
       if d.getVar('BASEMACHINE', True) == 'qcs40x':
               d.setVar('WLAN_CONFIG', 'qcs40x.snoc.perf')
}

EXTRA_OEMAKE += "CONFIG_QCA_CLD_WLAN_PROFILE=${WLAN_CONFIG}"
# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_DUPWHITELIST.
SSTATE_DUPWHITELIST += "${STAGING_DIR}/${MACHINE}${includedir}/qcacld/wlan_nlink_common.h"

do_patch () {
    mv ${WORKDIR}/wlan/${QCAAPI_REV} ${WORKDIR}/wlan/fw-api
    mv ${WORKDIR}/wlan/${QCACMN_REV} ${WORKDIR}/wlan/qca-wifi-host-cmn
}

do_install () {
    module_do_install

    install -d ${FIRMWARE_PATH}
    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/

    #copying wlan.ko to STAGING_DIR_TARGET
    WLAN_KO=${@oe.utils.conditional('PERF_BUILD', '1', '${STAGING_DIR_TARGET}-perf', '${STAGING_DIR_TARGET}', d)}
    install -d ${WLAN_KO}/wlan
    install -m 0644 ${S}/wlan.ko ${WLAN_KO}/wlan/
    ln -s /persist/wlan_mac.bin ${FIRMWARE_PATH}/wlan_mac.bin
}

do_module_signing() {
    if [ -f ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ]; then
        bbnote "Signing ${PN} module"
        ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PROVIDES_NAME}/lib/modules/${KERNEL_VERSION}/extra/wlan.ko
    elif [ -f ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ]; then
        ${STAGING_KERNEL_BUILDDIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.x509 ${PKGDEST}/${PN}/lib/modules/${KERNEL_VERSION}/extra/wlan.ko
    else
        bbnote "${PN} module is not being signed"
    fi
}

addtask module_signing after do_package before do_package_write_ipk
