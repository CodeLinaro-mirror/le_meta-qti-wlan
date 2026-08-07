inherit linux-kernel-base deploy module

DESCRIPTION = "QTI WLAN platform driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=801f80980d171dd6425610833a22dbe6"

DEPENDS += "virtual/kernel virtual/kernel-toolchain-native qmi-framework linux-msm-headers"
COMPATIBLE_MACHINE = "pebble"

PROVIDES = "kernel-module-wlan-platform"
FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/platform/"
S = "${WORKDIR}/wlan/platform"
B = "${S}"


MODULE_ICNSS = "cnss_prealloc.ko cnss_utils.ko cnss_nl.ko wlan_firmware_service.ko icnss2.ko"
MODULE_LIST:pebble = "${MODULE_ICNSS}"

SOCINCLUDE = "-I${STAGING_INCDIR}/soc-repo -I${STAGING_INCDIR}/soc-repo/uapi"
EXTRA_OEMAKE:append = " M=${S}"
EXTRA_OEMAKE:append = " TARGET_SUPPORT=${BASEMACHINE}"
EXTRA_OEMAKE:append = " NOSTDINC_FLAGS='${SOCINCLUDE} -nostdinc'"
EXTRA_OEMAKE:append = " KCPPFLAGS='-I${STAGING_INCDIR}'"
EXTRA_OEMAKE:append = " 'EXTRA_CFLAGS=-I${S}/inc -I${S}/cnss_utils' "

# ============ Toolchain configuration ============
KERNEL_CC = "${STAGING_BINDIR_NATIVE}/clang/bin/clang \
             -target ${TARGET_ARCH}${TARGET_VENDOR}-${TARGET_OS}"
KERNEL_LD = "${STAGING_BINDIR_NATIVE}/clang/bin/ld.lld"
KERNEL_AR = "${STAGING_BINDIR_NATIVE}/clang/bin/llvm-ar"
KERNEL_OBJCOPY = "${STAGING_BINDIR_NATIVE}/clang/bin/llvm-objcopy"
KERNEL_STRIP = "${STAGING_BINDIR_NATIVE}/clang/bin/llvm-strip"

MAKE_TARGETS = "modules"

do_unpack[deptask] = "do_populate_sysroot"

do_configure[depends] = "virtual/kernel:do_shared_workdir"
do_configure[noexec] = "1"

do_install() {
    install -d ${S}/unstripped
    install -m 0755 `find ${S} -name "*.ko"` -D ${S}/unstripped

    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}

    for module in ${MODULE_LIST}; do
        ${KERNEL_STRIP} --strip-debug ${S}/unstripped/${module} \
            -o ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/${module}
    done

    install -m 0644 ${B}/Module.symvers -D ${D}${includedir}/kernel-module-${BPN}/Module.symvers
}

do_deploy() {
    install -d ${DEPLOYDIR}/kernel_modules
    install -m 0755 ${S}/unstripped/*.ko ${DEPLOYDIR}/kernel_modules
}

addtask do_deploy after do_install
