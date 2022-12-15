inherit linux-kernel-base deploy

DESCRIPTION = "QTI WLAN platform driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=801f80980d171dd6425610833a22dbe6"

DEPENDS += "qmi-framework"
do_unpack[deptask] = "do_populate_sysroot"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/platform/"

SRC_URI += "file://kernel-5.15/kernel_platform"
SRC_URI += "file://kernel-5.15/out/msm-kernel-kalama_le-${KERNEL_VARIANT}"

S = "${WORKDIR}/wlan/platform"

do_configure[depends] = "virtual/kernel:do_shared_workdir"

do_configure[noexec] = "1"

MODULE_NAME = "wlan-platform"
MODULE_LIST = "cnss_prealloc.ko cnss_utils.ko cnss_nl.ko cnss_plat_ipc_qmi_svc.ko wlan_firmware_service.ko cnss2.ko"

KERNEL_VERSION = "${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"

do_compile() {
    cd ${WORKDIR}/kernel-${PREFERRED_VERSION_linux-msm}/kernel_platform && \
    BUILD_CONFIG=msm-kernel/${KERNEL_CONFIG} \
    EXT_MODULES=../../wlan/platform \
    ROOTDIR=${WORKSPACE}/ \
    MODULE_OUT=${S} \
    OUT_DIR=${WORKDIR}/kernel-5.15/out/msm-kernel-kalama_le-${KERNEL_VARIANT}/ \
    KERNEL_UAPI_HEADERS_DIR=${STAGING_KERNEL_BUILDDIR} \
    ./build/build_module.sh
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
