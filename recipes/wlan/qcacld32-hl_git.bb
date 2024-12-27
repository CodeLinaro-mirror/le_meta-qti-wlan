inherit autotools-brokensep module qperf

DESCRIPTION = "WLAN CLD3.0 high latency driver"
LICENSE = "ISC & BSD-3-Clause & BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d"
LIC_FILES_CHKSUM += "file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"
LIC_FILES_CHKSUM += "file://${COREBASE}/meta-qti-bsp/files/common-licenses/BSD-3-Clause-Clear;md5=3771d4920bd6cdb8cbdf1e8344489ee0"

python __anonymous () {
    d.setVar('WLAN_MODULE_NAME', 'wlan')
    d.setVar('CHIP_NAME', '')
}

FILES:${PN}     += "lib/firmware/wlan/*"
FILES:${PN}     += "${base_libdir}/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_NAME}.ko"
# The inherit of module.bbclass will automatically name module packages with
# kernel-module-" prefix as required by the oe-core build environment. Also it
# replaces '_' with '-' in the module name.
RPROVIDES:${PN} += "${@'kernel-module-${WLAN_MODULE_NAME}-${KERNEL_VERSION}'.replace('_', '-')}"
PROVIDES_NAME   = "kernel-module-${WLAN_MODULE_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r0"

#This DEPENDS is to serialize kernel module builds
DEPENDS = "rtsp-alg"

do_configure[depends] += "virtual/kernel:do_shared_workdir"
FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"

SRC_URI:append = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_sdio_qca6174.ini"
SRC_URI:append = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"

S = "${WORKDIR}/wlan/qcacld-3.0/"
S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_ALLOW_OVERLAP_FILES.
SSTATE_ALLOW_OVERLAP_FILES += "${STAGING_DIR}/${MACHINE}${includedir}/qcacld/wlan_nlink_common.h"


# Append the chip name to firmware installation path
CHIP_NAME_APPEND = "${@oe.utils.conditional('CHIP_NAME', '', '', '/${CHIP_NAME}', d)}"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld${CHIP_NAME_APPEND}"

# Explicitly disable LL to enable HL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CLD_LL_CORE=n CONFIG_CNSS_PCI=n MODNAME=${WLAN_MODULE_NAME} CHIP_NAME=${CHIP_NAME} CONFIG_QCA_CLD_WLAN_PROFILE=qca6174"

EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"
do_compile[depends] += "virtual/kernel:do_shared_workdir"
do_compile[cleandirs] += "${WORKDIR}/out/${KERNEL_DEFCONFIG}"

do_compile:prepend() {
    sed -i '$a\ccflags-y += -Wno-implicit-fallthrough' ${S}/Kbuild
}

do_compile() {
    variant="${@bb.utils.contains('DEBUG_BUILD','1', "debug", "perf", d)}"
    cd ${KERNEL_PLATFORM_PATH}
    ENABLE_DDK_BUILD=${ENABLE_DDK_BUILD} \
    TARGET_BOARD_PLATFORM=${TARGET_BOARD_PLATFORM} \
    BUILD_CONFIG=${KERNEL_BUILD_CONFIG} \
    EXT_MODULES=${EXT_MODULES} \
    ROOTDIR=${WORKDIR}/ \
    MODULE_OUT=${S} \
    OUT_DIR=${KERNEL_OUT_PATH}/ \
    VARIANT=${variant}_defconfig \
    KERNEL_UAPI_HEADERS_DIR=${STAGING_KERNEL_BUILDDIR} \
    ./build/build_module.sh
}

do_install () {
    install -d ${FIRMWARE_PATH}
    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S}/${WLAN_MODULE_NAME}.ko -D ${D}/${base_libdir}/modules/${KERNEL_VERSION}/extra/${WLAN_MODULE_NAME}.ko
    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/
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
