inherit autotools-brokensep module qperf

DESCRIPTION = "WLAN CLD3.0 high latency driver"
LICENSE = "ISC & BSD-3-Clause & BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d"
LIC_FILES_CHKSUM += "file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"
LIC_FILES_CHKSUM += "file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause-Clear;md5=7a434440b651f4a472ca93716d01033a"

python __anonymous () {
    d.setVar('WLAN_MODULE_NAME', 'wlan')
    d.setVar('CHIP_NAME', '')
}

FILES_${PN}     += "lib/firmware/wlan/*"
FILES_${PN}     += "${base_libdir}/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_NAME}.ko"
# The inherit of module.bbclass will automatically name module packages with
# kernel-module-" prefix as required by the oe-core build environment. Also it
# replaces '_' with '-' in the module name.
RPROVIDES_${PN} += "${@'kernel-module-${WLAN_MODULE_NAME}-${KERNEL_VERSION}'.replace('_', '-')}"
PROVIDES_NAME   = "kernel-module-${WLAN_MODULE_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r0"

#This DEPENDS is to serialize kernel module builds
DEPENDS = "rtsp-alg"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"

SRC_URI_append = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_sdio_qca6174.ini"
SRC_URI_append = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"

S = "${WORKDIR}/wlan/qcacld-3.0/"
S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"

# Append the chip name to firmware installation path
CHIP_NAME_APPEND = "${@oe.utils.conditional('CHIP_NAME', '', '', '/${CHIP_NAME}', d)}"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld${CHIP_NAME_APPEND}"

# Explicitly disable LL to enable HL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CLD_LL_CORE=n CONFIG_CNSS_PCI=n MODNAME=${WLAN_MODULE_NAME} CHIP_NAME=${CHIP_NAME} CONFIG_QCA_CLD_WLAN_PROFILE=qca6174 CONFIG_WLAN_FEATURE_DSRC=n"
do_compile_prepend() {
    sed -i '$a\ccflags-y += -Wno-implicit-fallthrough' ${S}/Kbuild
}

do_install () {
    module_do_install

    install -d ${FIRMWARE_PATH}
    #copying wlan.ko to STAGING_DIR_TARGET
    WLAN_KO=${@oe.utils.conditional('PERF_BUILD', '1', '${STAGING_DIR_TARGET}-perf', '${STAGING_DIR_TARGET}', d)}
    install -d ${WLAN_KO}/wlan
    install -m 0644 ${S}/${WLAN_MODULE_NAME}.ko ${WLAN_KO}/wlan/

    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_sdio_qca6174.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/wlan_mac.bin ${FIRMWARE_PATH}/wlan_mac.bin
    chmod -R 0664 ${FIRMWARE_PATH}/wlan_mac.bin
}

do_module_signing() {
    if [ -f ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ]; then
        ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PN}/lib/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_NAME}.ko
    fi
}

addtask module_signing after do_package before do_package_write_ipk
