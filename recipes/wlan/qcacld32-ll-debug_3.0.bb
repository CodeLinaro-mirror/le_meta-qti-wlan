inherit linux-kernel-base deploy module

DESCRIPTION = "Qualcomm Technologies, Inc. WLAN CLD3.0 low latency driver"
LICENSE = "ISC & BSD-3-Clause & GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/ISC;md5=f3b90e78ea0cffb20bf5cca7947a896d \
file://${COREBASE}/meta/files/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9 \
file://${COREBASE}/meta/files/common-licenses/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

COMPATIBLE_MACHINE = "pebble"

TARGET_WLAN_CHIP ?= "wlan"
TARGET_WLAN_CHIP:pebble = "wcn7750"

MODULE_NAME = "qca_cld3_${TARGET_WLAN_CHIP}"

MACHINE_CONFIG = "${BASEMACHINE}"
MACHINE_CONFIG:pebble = "sun"

DEPENDS += "kernel-module-wlan-platform linux-msm-headers virtual/kernel virtual/kernel-toolchain-native"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/qcacld-3.0/"
SRC_URI += "file://wlan/qca-wifi-host-cmn/"
SRC_URI += "file://wlan/fw-api/"
SRC_URI += "file://device/qcom/wlan/${MACHINE_CONFIG}/"
SRC_URI += "file://wlan_load.conf"
SRC_URI += "file://wlan/platform/"

S1 = "${WORKDIR}/wlan/qca-wifi-host-cmn"
S = "${WORKDIR}/wlan/qcacld-3.0"

WLAN_CONFIG = "${TARGET_WLAN_CHIP}"

# The common header file, 'wlan_nlink_common.h' can be installed from other
# qcacld recipes too. To suppress the duplicate detection error, add it to
# SSTATE_ALLOW_OVERLAP_FILES.
SSTATE_ALLOW_OVERLAP_FILES += "${STAGING_DIR}/${BASEMACHINE}${includedir}/qcacld/wlan_nlink_common.h"

EXTRA_OEMAKE:append = " M=${S}"
EXTRA_OEMAKE:append = " WLAN_PROFILE=${MODULE_NAME}"

# Passing WLAN_ROOT to explicitly keeps the include paths short.
EXTRA_OEMAKE:append = " WLAN_ROOT=."

# Passing CNSS and WLAN compile configs
EXTRA_OEMAKE:append = " DYNAMIC_SINGLE_CHIP=${TARGET_WLAN_CHIP}"
EXTRA_OEMAKE:append = " MODNAME=${MODULE_NAME}"
EXTRA_OEMAKE:append = " DEVNAME=${MODULE_NAME}"
EXTRA_OEMAKE:append = " BOARD_PLATFORM=${BASEMACHINE}"
EXTRA_OEMAKE:append = " CONFIG_QCA_CLD_WLAN=m"
EXTRA_OEMAKE:append = " WLAN_CTRL_NAME=wlan"
EXTRA_OEMAKE:append = " CONFIG_QCA_CLD_WLAN_PROFILE=${WLAN_CONFIG}"
EXTRA_OEMAKE:append = " CONFIG_CNSS_OUT_OF_TREE=y"
EXTRA_OEMAKE:append = " CONFIG_ICNSS2=m"
EXTRA_OEMAKE:append = " CONFIG_WLAN_TX_MON_2_0=n"
EXTRA_OEMAKE:append = " CONFIG_WLAN_DP_LOCAL_PKT_CAPTURE=n"
EXTRA_OEMAKE:append = " KERNEL_SUPPORTS_NESTED_COMPOSITES=n"
EXTRA_OEMAKE:append = " BUILD_DEBUG_VERSION=y"
EXTRA_OEMAKE:append = " CONFIG_CNSS_GENL=m"
EXTRA_OEMAKE:append = " TARGET_SUPPORT=${BASEMACHINE}"

# Resolve LINUX include path
SOCINCLUDE = "-I${STAGING_INCDIR}/soc-repo -I${STAGING_INCDIR}/soc-repo/uapi"
EXTRA_OEMAKE:append = " NOSTDINC_FLAGS='${SOCINCLUDE} -nostdinc'"
EXTRA_OEMAKE:append = " KCPPFLAGS='-I${STAGING_INCDIR}'"

# ============ Toolchain configuration ============
KERNEL_CC = "${STAGING_BINDIR_NATIVE}/clang/bin/clang -target ${TARGET_ARCH}${TARGET_VENDOR}-${TARGET_OS}"
KERNEL_LD = "${STAGING_BINDIR_NATIVE}/clang/bin/ld.lld"
KERNEL_AR = "${STAGING_BINDIR_NATIVE}/clang/bin/llvm-ar"
KERNEL_OBJCOPY = "${STAGING_BINDIR_NATIVE}/clang/bin/llvm-objcopy"
KERNEL_STRIP = "${STAGING_BINDIR_NATIVE}/clang/bin/llvm-strip"

# The source Makefile only defines an 'all:' not a 'modules' target.
# Drive 'all' instead of 'modules'.
MAKE_TARGETS = "all"

do_unpack[deptask] = "do_populate_sysroot"

do_compile[depends] += "virtual/kernel:do_shared_workdir"

do_install() {
    install -d ${S}/unstripped
    install -m 0755 ${S}/${MODULE_NAME}.ko -D ${S}/unstripped

    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}
    install -d ${D}${includedir}/qcacld/

    install -m 0644 ${S1}/utils/nlink/inc/wlan_nlink_common.h ${D}${includedir}/qcacld/

    ${KERNEL_STRIP} --strip-debug ${S}/unstripped/${MODULE_NAME}.ko \
        -o ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/${MODULE_NAME}.ko

    # auto load
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0755 ${WORKDIR}/wlan_load.conf -D ${D}${sysconfdir}/modules-load.d/wlan_load.conf
}

do_deploy () {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/${MODULE_NAME}.ko ${DEPLOYDIR}/kernel_modules
}

FILES:${PN} += "${sysconfdir}/*"

addtask do_deploy after do_install
