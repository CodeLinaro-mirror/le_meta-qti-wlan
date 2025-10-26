inherit module deploy

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

PROVIDES_NAME   = "kernel-module-wlan"
RPROVIDES:${PN} += "${PROVIDES_NAME}-${KERNEL_VERSION}"

DEFAULT_PREFERENCE = "-1"

TARGET_WLAN_CHIP = "kiwi_v2"
WLAN_CHIP = "qca_cld3"

PR = "r8"
# This DEPENDS is to serialize kernel module builds
DEPENDS = " virtual/kernel"
DEPENDS += "wlan-platform"

FILES:${PN}     += "lib/firmware/wlan/*"
FILES:${PN}     += "lib/modules/${KERNEL_VERSION}/extra/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko"
FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://device/qcom/wlan/${BASEMACHINE}/"
SRC_URI += "file://wlan_load.conf"
SRC_URI += "file://wlan/platform/"
SRC_URI += "file://qcacld-kbuild.patch"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn/"
S = "${WORKDIR}/wlan/qcacld-3.0"

RPROVIDES:${PN} += "kernel-module-qca-cld3-kiwi-v2-${KERNEL_VERSION}"
CLANG_BIN = "${WORKDIR}/recipe-sysroot-native/usr/bin/clang/bin"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/${WLAN_CHIP}_${TARGET_WLAN_CHIP}"

# Explicitly disable HL to enable LL as current WLAN driver is not having
# simultaneous support of HL and LL.

KERNEL_CC = "${STAGING_BINDIR_NATIVE}/clang/bin/clang -target ${TARGET_ARCH}${TARGET_VENDOR}-${TARGET_OS}"
BUILD_FLAGS = "WLAN_ROOT=${S} CONFIG_QCA_CLD_WLAN_PROFILE=${TARGET_WLAN_CHIP} MODNAME=${WLAN_CHIP}_${TARGET_WLAN_CHIP}"

ADDITIONAL_CONFIGS = "CONFIG_CLD_HL_SDIO_CORE=n CONFIG_CNSS_SDIO=n CONFIG_QCA_CLD_WLAN=m WLAN_CTRL_NAME=wlan KERNEL_SUPPORTS_NESTED_COMPOSITES=n CONFIG_CNSS_OUT_OF_TREE=y CONFIG_CNSS2=m CONFIG_CNSS2_QMI=y CONFIG_CNSS_QMI_SVC=m CONFIG_CNSS_PLAT_IPC_QMI_SVC=m CONFIG_CNSS_GENL=m CONFIG_WCNSS_MEM_PRE_ALLOC=m CONFIG_CNSS_UTILS=m CONFIG_QDF_TEST=n CONFIG_WLAN_CFR_ENABLE=n CONFIG_RX_FISA=n CONFIG_DP_SWLM=n"

do_compile() {
    bbnote "==============================================================="
    bbnote "EXTRA_OEMAKE = ${EXTRA_OEMAKE}"
    bbnote "==============================================================="
    #unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake CC="${KERNEL_CC}" ${BUILD_FLAGS} -C ${STAGING_KERNEL_BUILDDIR} \
       KBUILD_EXTRA_SYMBOLS=${STAGING_DIR_HOST}/lib/modules/${KERNEL_VERSION}/cnsswlan-kernel/Module.symvers \
       ${ADDITIONAL_CONFIGS} \
       KCFLAGS=-D__ANDROID_COMMON_KERNEL__ \
       M=${S} \
       modules
}

do_install() {
    install -d ${S}/unstripped
    cp -f ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko ${S}/unstripped
    ${CLANG_BIN}/llvm-strip --strip-unneeded ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko
    install -m 0755 ${S}/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko -D ${D}/${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0755 ${WORKDIR}/wlan_load.conf -D ${D}/${sysconfdir}/modules-load.d/wlan_load.conf
    install -d ${FIRMWARE_PATH}
    install -m 0644 ${WORKDIR}/device/qcom/wlan/${BASEMACHINE}/WCNSS_qcom_cfg_${TARGET_WLAN_CHIP}_LE.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_module_signing() {
    ${STAGING_KERNEL_BUILDDIR}/scripts/sign-file sha512 ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.pem ${STAGING_KERNEL_BUILDDIR}/certs/signing_key.x509 ${PKGDEST}/${PN}/lib/modules/${KERNEL_VERSION}/extra/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko
}

# Deploying unstripped modules is done for crash analysis
do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/${WLAN_CHIP}_${TARGET_WLAN_CHIP}.ko ${DEPLOYDIR}/kernel_modules
}

do_patch() {
     cd ${S}
     patch -p1 < ${WORKDIR}/qcacld-kbuild.patch
}

FILES:${PN} += "${sysconfdir}/*"
FILES:${PN} += "${nonarch_base_libdir}/modules/*"

addtask do_deploy after do_install

addtask module_signing after do_package before do_package_write_ipk
