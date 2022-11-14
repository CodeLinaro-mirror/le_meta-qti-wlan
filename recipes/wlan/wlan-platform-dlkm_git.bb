
inherit autotools-brokensep module qperf

DESCRIPTION = "Build wlan platform drivers to kernel module"
LICENSE = "GPL-2.0"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=801f80980d171dd6425610833a22dbe6"
SUMMARY = "Wlan platform drivers"
_MODNAME = "wlan-platform-dlkm"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/cnss2.ko"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/cnss_nl.ko"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/cnss_utils.ko"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/cnss_plat_ipc_qmi_svc.ko"
FILES_${PN}     += "lib/modules/${KERNEL_VERSION}/extra/wlan_firmware_service.ko"
FILES_${PN}     += "usr/inc/*"
PROVIDES_NAME   = "kernel-module-${_MODNAME}"
RPROVIDES_${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

WLAN_PLATFORM_CFG = " CONFIG_CNSS_OUT_OF_TREE=y \
	CONFIG_CNSS2=m \
	USE_EXTERNAL_CONFIGS=y \
	CONFIG_AUTO_PROJECT=y \
	CONFIG_CNSS2_QMI=y \
	CONFIG_CNSS2_DEBUG=y \
	CONFIG_CNSS_QMI_SVC=m \
	CONFIG_CNSS_PLAT_IPC_QMI_SVC=m \
	CONFIG_CNSS_GENL=m CONFIG_CNSS_UTILS=m"
EXTRA_OEMAKE:append = "${@bb.utils.contains('PREFERRED_VERSION_linux-msm', '5.15', '${WLAN_PLATFORM_CFG}', '', d)}"

do_unpack[deptask] = "do_populate_sysroot"
PR = "r8"

DEPENDS = "virtual/kernel"
DEPENDS += "${@bb.utils.contains_any('BASEMACHINE', 'sa525m', 'wlan-devicetree', '', d)}"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/platform/"
S = "${WORKDIR}/wlan/platform/"

EXTRA_OEMAKE += "MODNAME=${_MODNAME}"
LDFLAGS_aarch64 = "-O1 --hash-style=gnu --as-needed"
inherit systemd
FILES_${PN}     += "usr/bin/init.qti.cnss2_on.sh"
FILES_${PN}     += "usr/bin/init.qti.cnss2_off.sh"

SRC_URI_append = " file://init_qti_cnss2_auto.service"
SYSTEMD_SERVICE_${PN} = "init_qti_cnss2_auto.service"

# disable wlan service on boot for sdxpoorwills-auto
SYSTEMD_AUTO_ENABLE_${PN} = "disable"

SRC_URI_append = " file://init.qti.cnss2_on.sh"
SRC_URI_append = " file://init.qti.cnss2_off.sh"

do_install() {
    module_do_install
    install -d ${D}${includedir}

    #copying cnss2 and other modules to STAGING_DIR_TARGET
    CNSS2_KO=${@oe.utils.conditional('PERF_BUILD', '1', '${STAGING_DIR_TARGET}-perf', '${STAGING_DIR_TARGET}', d)}
    install -d ${CNSS2_KO}/cnss2
    install -d ${CNSS2_KO}/cnss_genl
    install -d ${CNSS2_KO}/cnss_utils
    install -d ${CNSS2_KO}/inc
    install -m 0644 ${S}/cnss2/cnss2.ko ${CNSS2_KO}/cnss2/
    install -m 0644 ${S}/cnss_genl/cnss_nl.ko ${CNSS2_KO}/cnss_genl/
    install -m 0644 ${S}/cnss_utils/cnss_utils.ko ${CNSS2_KO}/cnss_utils/
    install -m 0644 ${S}/cnss_utils/cnss_plat_ipc_qmi_svc.ko ${CNSS2_KO}/cnss_utils/
    install -m 0644 ${S}/cnss_utils/wlan_firmware_service.ko ${CNSS2_KO}/cnss_utils/
    install -m 0644 ${S}/inc/* ${D}${includedir}/
}

do_install_append() {
    install -d ${D}${bindir}
    install -D -m 0755 ${WORKDIR}/init.qti.cnss2_on.sh ${D}${bindir}/init.qti.cnss2_on.sh
    install -D -m 0755 ${WORKDIR}/init.qti.cnss2_off.sh ${D}${bindir}/init.qti.cnss2_off.sh
    # Install systemd service file
    if ${@bb.utils.contains('DISTRO_FEATURES','systemd','true','false',d)}; then
        install -m 0644 ${WORKDIR}/init_qti_cnss2_auto.service -D ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service
    fi
}


do_module_signing() {
    if [ -f ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ]; then
        bbnote "Signing ${PN} module"
        ${STAGING_KERNEL_DIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/signing_key.priv ${STAGING_KERNEL_BUILDDIR}/signing_key.x509 ${PKGDEST}/${PN}/lib/modules/${KERNEL_VERSION}/extra/cnss2/cnss2.ko
    elif [ -f ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ]; then
        ${STAGING_KERNEL_BUILDDIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.x509 ${PKGDEST}/kernel-module-cnss2-${KERNEL_VERSION}/lib/modules/${KERNEL_VERSION}/extra/cnss2/cnss2.ko
    else
        bbnote "${PN} module is not being signed"
    fi
}

addtask module_signing after do_package before do_package_write_ipk
