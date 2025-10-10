inherit autotools-brokensep module qperf

DESCRIPTION = "WLAN CLD3.0 high latency driver"
PACKAGE_ARCH = "${MACHINE_ARCH}"
LICENSE = "ISC & BSD-3-Clause & BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d"
LIC_FILES_CHKSUM += "file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"
LIC_FILES_CHKSUM += "file://${COREBASE}/meta-qti-bsp/files/common-licenses/BSD-3-Clause-Clear;md5=3771d4920bd6cdb8cbdf1e8344489ee0"

_LINUX_BUILD_TOP = "${WORKDIR}/wlan"
EXTRA_OEMAKE:append = " LINUX_BUILD_TOP=${_LINUX_BUILD_TOP}"

_MODNAME = "qca6574au-3"
FW_PATH_NAME = "qca6174-3"

FILES:${PN} += "${nonarch_base_libdir}/firmware/wlan/*"
FILES:${PN} += "${nonarch_base_libdir}/firmware/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${_MODNAME}.ko"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/*"
FILES:${PN} += "/usr/lib/firmware/wlan/*"
FILES:${PN} += "/usr/lib/firmware/*"
FILES:${PN} += "/usr/lib/firmware/${_MODNAME}"
FILES:${PN} += "/usr/bin/*"
# The inherit of module.bbclass will automatically name module packages with
# kernel-module-" prefix as required by the oe-core build environment. Also it
# replaces '_' with '-' in the module name.
PROVIDES_NAME   = "kernel-module-${_MODNAME}"
RPROVIDES:${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"
do_configure[noexec] = "1"
#This DEPENDS is to serialize kernel module builds
#DEPENDS = "rtsp-alg"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"

SRC_URI:append = " file://device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_sdio_qca6174.ini"
SRC_URI:append = " file://device/qcom/wlan/sdx_auto/wlan_mac.bin"

S = "${WORKDIR}/wlan/qcacld-3.0/"
S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
FIRMWARE_PATH = "${D}/usr/lib/firmware/wlan/qca_cld/${_MODNAME}"

EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

KERNEL_CC += "-w"
RM_WORK_EXCLUDE += "${PN}"

DEPENDS:append:sa510m = "wlan-platform-dlkm"
LDFLAGS:aarch64 = "-O1 --hash-style=gnu --as-needed"

# Explicitly disable LL to enable HL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CLD_LL_CORE=n CONFIG_CLD_HL_SDIO_CORE=y CONFIG_CNSS_PCI=n MODNAME=${WLAN_MODULE_NAME} CHIP_NAME=${CHIP_NAME} CONFIG_QCA_CLD_WLAN_PROFILE=qca6174 CONFIG_WLAN_FEATURE_DSRC=n CONFIG_WLAN_NAPI=n"
do_compile:prepend() {
    sed -i '$a\ccflags-y += -Wno-implicit-fallthrough' ${S}/Kbuild
}

# ------------------------------
# Board platform selection
# ------------------------------
# Default to sa510m; override per MACHINE or in local.conf as needed.
TARGET_BOARD_PLATFORM ?= "sa510m"
# If your MACHINE is named 'sa510m-1g', this maps the platform string to 'sa510m.1g'
TARGET_BOARD_PLATFORM:sa510m-1g = "sa510m.1g"

do_compile:sa510m() {
    variant="${@bb.utils.contains('DEBUG_BUILD','1', "debug", "perf", d)}"
    cd ${KERNEL_PLATFORM_PATH}
    ln -sf ../../wlan
    ENABLE_DDK_BUILD=true \
    TARGET_BOARD_PLATFORM=${TARGET_BOARD_PLATFORM} \
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
    WLAN_KO=${D}/${base_libdir}/modules/${KERNEL_VERSION}/extra
    install -d ${WLAN_KO}
    install -m 0644 ${S}/${_MODNAME}.ko ${WLAN_KO}/${_MODNAME}.ko

    install -d ${FIRMWARE_PATH}
    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/

	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_sdio_qca6174.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
    install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/wlan_mac.bin ${FIRMWARE_PATH}/wlan_mac.bin
    chmod -R 0664 ${FIRMWARE_PATH}/wlan_mac.bin
}

do_module_signing() {
	if [ -f ${KERNEL_PREBUILT_PATH} ]; then
		WLAN_KO=${D}/${base_libdir}/modules/${KERNEL_VERSION}/extra
		export LD_LIBRARY_PATH=${KERNEL_PREBUILT_PATH}/dist
		${KERNEL_PREBUILT_PATH}/dist/sign-file sha1 ${KERNEL_PREBUILT_PATH}/dist/signing_key.pem ${KKERNEL_PREBUILT_PATH}/dist/signing_key.x509 ${WLAN_KO}/${_MODNAME}.ko
    fi
}

addtask module_signing after do_package before do_package_qa do_package_write_ipk
