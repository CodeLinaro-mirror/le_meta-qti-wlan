inherit module linux-kernel-base deploy

DESCRIPTION = "QTI WLAN platform driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=801f80980d171dd6425610833a22dbe6"
MODULE_NAME = "wlan-platform"

DEFAULT_PREFERENCE = "-1"
DEPENDS += "virtual/kernel virtual/kernel-toolchain-native"

PROVIDES_NAME   = "wlan-platform"
FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/platform/"
S = "${WORKDIR}/wlan/platform"

RPROVIDES:${PN} += "kernel-module-cnss-nl-${KERNEL_VERSION}"
RPROVIDES:${PN} += "kernel-module-cnss-plat-ipc-qmi-svc-${KERNEL_VERSION}"
RPROVIDES:${PN} += "kernel-module-cnss-prealloc-${KERNEL_VERSION}"
RPROVIDES:${PN} += "kernel-module-cnss2-${KERNEL_VERSION}"
RPROVIDES:${PN} += "kernel-module-cnss-utils-${KERNEL_VERSION}"
RPROVIDES:${PN} += "kernel-module-wlan-firmware-service-${KERNEL_VERSION}"

MODULE_CNSS = "cnss_prealloc.ko cnss_utils.ko cnss_nl.ko cnss_plat_ipc_qmi_svc.ko wlan_firmware_service.ko cnss2.ko"
MODULE_LIST = "${@bb.utils.contains('MACHINE', 'ar-sg1', '${MODULE_CNSS}', '', d)}"

KERNEL_CC = "${STAGING_BINDIR_NATIVE}/clang/bin/clang -target ${TARGET_ARCH}${TARGET_VENDOR}-${TARGET_OS}"

PLATFORM_MODULE_FLAGS = "CONFIG_QCA_CLD_WLAN_PROFILE=default CONFIG_CNSS_OUT_OF_TREE=y CONFIG_CNSS2=m CONFIG_CNSS2_QMI=y CONFIG_CNSS2_DEBUG=y CONFIG_CNSS_QMI_SVC=m CONFIG_CNSS_PLAT_IPC_QMI_SVC=m CONFIG_CNSS_GENL=m CONFIG_WCNSS_MEM_PRE_ALLOC=m CONFIG_CNSS_UTILS=m CONFIG_CNSS2_SSR_DRIVER_DUMP=y CONFIG_PCI_MSM=m"

EXTRA_OEMAKE += "'EXTRA_CFLAGS=-I${S}/inc -I${S}/cnss_utils'"

do_configure[noexec] = "1"
do_compile() {
     oe_runmake CC="${KERNEL_CC}" \
         -C ${STAGING_KERNEL_BUILDDIR} \
         ${PLATFORM_MODULE_FLAGS} M=${S} \
         modules
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

do_module_signing() {
    for module in ${MODULE_LIST}; do
         ${STAGING_KERNEL_BUILDDIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.x509 ${PKGDEST}/${PROVIDES_NAME}/lib/modules/${KERNEL_VERSION}/${module}
    done
}

# Deploying unstripped modules is done for crash analysis
do_deploy() {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/*.ko ${DEPLOYDIR}/kernel_modules
}

FILES:${PN} += "${sysconfdir}/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/*"

addtask do_deploy after do_install

addtask module_signing after do_package before do_package_write_ipk
