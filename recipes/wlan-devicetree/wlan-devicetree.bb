inherit linux-kernel-base deploy

SUMMARY = "Wlan devicetree"
DESCRIPTION = "Build QTI wlan devicetree to dtbo"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"

DEPENDS += "virtual/kernel"
DEPENDS:alor += " coreutils-native rsync-native "
DEPENDS:pebble += " coreutils-native rsync-native "

FILESEXTRAPATHS:prepend := "${WORKSPACE}/wlan:"
SRC_URI = "file://wlan-devicetree/"
S = "${WORKDIR}/wlan-devicetree"

do_configure[depends] = "virtual/kernel:do_shared_workdir"

KERNEL_VERSION = "${@get_kernelversion_headers('${STAGING_KERNEL_BUILDDIR}')}"

EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

EXTRA_OEMAKE += "TARGET_SUPPORT=${BASEMACHINE}"

KERNEL_CC = "${STAGING_BINDIR_NATIVE}/clang/bin/clang -target ${TARGET_ARCH}${TARGET_VENDOR}-${TARGET_OS}"
KERNEL_KIT = "${@'${KERNEL_PREBUILT_PATH}' if d.getVar('MACHINE_USES_KERNEL_PREBUILTS') == 'True' else '${STAGING_KERNEL_BUILDDIR}'}"

do_compile[depends]   += "virtual/kernel:do_shared_workdir"
do_compile[cleandirs] += "${WORKDIR}/out/${KERNEL_DEFCONFIG}"
do_compile[lockfiles] = "${TMPDIR}/build_modules.lock"
do_compile() {
    cd ${KERNEL_PLATFORM_PATH}
    BUILD_CONFIG=msm-kernel/${KERNEL_CONFIG} \
    EXT_MODULES=${EXT_MODULES} \
    KERNEL_KIT=${KERNEL_PREBUILT_PATH} \
    MODULE_OUT=${S} \
    OUT_DIR=${WORKDIR}/out/${KERNEL_DEFCONFIG} \
    INPLACE_COMPILE=y \
    ./build/build_module.sh
}

do_compile:alor() {
    cd ${KERNEL_PLATFORM_PATH}
    BUILD_CONFIG=${KERNEL_BUILD_CONFIG} \
    EXT_MODULES=${EXT_MODULES} \
    KERNEL_KIT=${KERNEL_PREBUILT_PATH} \
    MODULE_OUT=${S} \
    OUT_DIR=${WORKDIR}/out/${KERNEL_DEFCONFIG} \
    INPLACE_COMPILE=y \
    ./build/build_module.sh dtbs
}

do_compile:pebble() {
    cd ${KERNEL_PLATFORM_PATH}
    BUILD_CONFIG=${KERNEL_BUILD_CONFIG} \
    VARIANT=${KERNEL_DEFCONFIG_VARIANT} \
    EXT_MODULES=${EXT_MODULES} \
    KERNEL_KIT=${KERNEL_KIT} \
    MODULE_OUT=${S} \
    OUT_DIR=${WORKDIR}/out/${KERNEL_DEFCONFIG} \
    INPLACE_COMPILE=y \
    TARGET_BOARD_PLATFORM=${TARGET_BOARD_PLATFORM} \
    ./build/build_module.sh dtbs
}

do_compile:ar-sg1() {
    oe_runmake CC="${KERNEL_CC}" \
          -C ${STAGING_KERNEL_BUILDDIR} \
          M=${S} \
          modules
}

do_compile:vienna() {
    cd ${KERNEL_PLATFORM_PATH}
    BUILD_CONFIG=${KERNEL_BUILD_CONFIG} \
    EXT_MODULES=${EXT_MODULES} \
    KERNEL_KIT=${KERNEL_PREBUILT_PATH} \
    MODULE_OUT=${S} \
    OUT_DIR=${WORKDIR}/out/${KERNEL_DEFCONFIG} \
    INPLACE_COMPILE=y \
    ./build/build_module.sh dtbs
}

do_deploy() {
    install -d ${DEPLOYDIR}/tech_dtbs
    install -m 0644 ${S}/*.dtbo ${DEPLOYDIR}/tech_dtbs/
}

addtask do_deploy after do_install

ALLOW_EMPTY:${PN} = "1"
