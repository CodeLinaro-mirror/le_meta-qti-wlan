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
DEPENDS_remove_qrbx210-rbx = "rtsp-alg"
DEPENDS_remove_qrb5165 = "rtsp-alg"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://qcacld-kbuild.patch"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0/"

FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.
EXTRA_OEMAKE += "CONFIG_CLD_HL_SDIO_CORE=n CONFIG_CNSS_SDIO=n"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_DUPWHITELIST.
SSTATE_DUPWHITELIST += "${STAGING_DIR}/${MACHINE}${includedir}/qcacld/wlan_nlink_common.h"

# NF perf image select WLAN perf config
NF_PERF = "${@oe.utils.conditional('MACHINE', 'qcs403-som2', oe.utils.conditional('PERF_BUILD', '1', '1', '0', d), '0', d)}"

do_patch() {
    cd ${S}
    patch -p1 < ${WORKDIR}/qcacld-kbuild.patch
}

do_install () {
    module_do_install
    if ${@oe.utils.conditional('NF_PERF', '1', 'true', 'false', d)}; then
        if [ -f ${S}/build_1 ]; then
            cp ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/wlan.ko ${S}/wlan_debug.ko
        fi
        if [ -f ${S}/build_2 ]; then
            mv ${S}/wlan_debug.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
            rm ${S}/build_2
        fi
    fi
    install -d ${FIRMWARE_PATH}
    install -d ${D}${includedir}/qcacld/
    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/

    #copying wlan.ko to STAGING_DIR_TARGET
    WLAN_KO=${@oe.utils.conditional('PERF_BUILD', '1', '${STAGING_DIR_TARGET}-perf', '${STAGING_DIR_TARGET}', d)}
    install -d ${WLAN_KO}/wlan
    install -m 0644 ${S}/wlan.ko ${WLAN_KO}/wlan/
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

do_compile() {
    # Build default wlan.ko, if NF_PERF is 1, move this build output to wlan_debug.ko
    unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake CONFIG_QCA_CLD_WLAN_PROFILE=default KERNEL_PATH=${STAGING_KERNEL_DIR}   \
        KERNEL_VERSION=${KERNEL_VERSION}    \
        CC="${KERNEL_CC}" LD="${KERNEL_LD}" \
        AR="${KERNEL_AR}" \
        O=${STAGING_KERNEL_BUILDDIR} \
        KBUILD_EXTRA_SYMBOLS="${KBUILD_EXTRA_SYMBOLS}" \
        ${MAKE_TARGETS}
    # NF perf build, make another perf WLAN build as default wlan.ko
    if ${@oe.utils.conditional('NF_PERF', '1', 'true', 'false', d)}; then
        touch ${S}/build_1
        do_install
        mv ${S}/build_1 ${S}/build_2
        unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
        oe_runmake CONFIG_QCA_CLD_WLAN_PROFILE=qcs40x.snoc.perf KERNEL_PATH=${STAGING_KERNEL_DIR}   \
            KERNEL_VERSION=${KERNEL_VERSION}    \
            CC="${KERNEL_CC}" LD="${KERNEL_LD}" \
            AR="${KERNEL_AR}" \
            O=${STAGING_KERNEL_BUILDDIR} \
            KBUILD_EXTRA_SYMBOLS="${KBUILD_EXTRA_SYMBOLS}" \
            ${MAKE_TARGETS}
    fi
}

addtask module_signing after do_package before do_package_write_ipk
