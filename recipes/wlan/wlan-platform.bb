inherit linux-kernel-base deploy

DESCRIPTION = "QTI WLAN platform driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=801f80980d171dd6425610833a22dbe6"

DEPENDS += "virtual/kernel qmi-framework"
do_unpack[deptask] = "do_populate_sysroot"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/platform/"

S = "${WORKDIR}/wlan/platform"

do_configure[depends] = "virtual/kernel:do_shared_workdir"

do_configure[noexec] = "1"

MODULE_NAME = "wlan-platform"

MODULE_ICNSS = "cnss_prealloc.ko cnss_utils.ko cnss_nl.ko cnss_plat_ipc_qmi_svc.ko wlan_firmware_service.ko icnss2.ko"
MODULE_CNSS = "cnss_prealloc.ko cnss_utils.ko cnss_nl.ko cnss_plat_ipc_qmi_svc.ko wlan_firmware_service.ko cnss2.ko"

MODULE_LIST = "${MODULE_CNSS}"
MODULE_LIST:qcs40x = "${MODULE_ICNSS}"
MODULE_LIST:qcm2290-mtp = "${MODULE_ICNSS}"

WLAN_VAR = ""
WLAN_VAR:qcs40x = "qcs40x"
WLAN_VAR:qcm2290-mtp = "qcs40x"

KERNEL_VERSION = "${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

EXT_COMPILE_CONFIG = " "
EXT_COMPILE_CONFIG:append:kalama = " CONFIG_PCIE_SWITCH_NTN3=y "
EXT_COMPILE_CONFIG:append:qrb5165 = " CONFIG_PCI_MSM=m "
EXT_COMPILE_CONFIG:append:qcs40x = " CONFIG_PCI_MSM=m "
EXT_COMPILE_CONFIG:append:qcm2290-mtp = " CONFIG_PCI_MSM=m "

do_compile[depends] += "virtual/kernel:do_shared_workdir"
do_compile[cleandirs] += "${WORKDIR}/out/${KERNEL_DEFCONFIG}"
do_compile() {
    cd ${KERNEL_PLATFORM_PATH}
    BUILD_CONFIG=msm-kernel/${KERNEL_CONFIG} \
    EXT_MODULES=${EXT_MODULES} \
    KERNEL_KIT=${KERNEL_PREBUILT_PATH} \
    MODULE_OUT=${S} \
    OUT_DIR=${WORKDIR}/out/${KERNEL_DEFCONFIG} \
    INPLACE_COMPILE=y \
    KERNEL_UAPI_HEADERS_DIR=${STAGING_KERNEL_BUILDDIR} \
    ./build/build_module.sh \
    ${EXT_COMPILE_CONFIG} \
    WLAN_BASEMACHINE=${WLAN_VAR}
}

do_install() {
    install -d ${S}/unstripped
    install -m 0755 `find ${S} -name *.ko` -D ${S}/unstripped

    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}

    # strip debug symbols
    for module in ${MODULE_LIST}; do
        ${STAGING_DIR_NATIVE}/usr/bin/aarch64-oe-linux/aarch64-oe-linux-strip \
            --strip-debug ${S}/unstripped/${module} -o ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/${module}
    done

    install ${WORKDIR}/wlan/platform/Module.symvers -D ${D}${base_libdir}/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers

}

do_deploy() {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/*.ko ${DEPLOYDIR}/kernel_modules
}

addtask do_deploy after do_install

FILES:${PN} += "${sysconfdir}/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/*"
FILES:${PN}:append:qcm2290-mtp-32 = " ${base_libdir}/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers "
FILES:${PN}:append:qcm4325-mtp-32 = " ${base_libdir}/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers "
