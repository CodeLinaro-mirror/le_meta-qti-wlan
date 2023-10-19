SUMMARY = "Realtek 88x2bu Drivers Kernel Modules"
DESCRIPTION = "This is the realtek usb wifi driver base on rtl88x2bu"

LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=fed54355545ffd980b814dab4a3b312c"

inherit linux-kernel-base deploy

DEPENDS += "virtual/kernel"

SRCREV = "12cfcd8cd8ec7115158df3d223510435541ddc32"

SRC_URI = "git://git.codelinaro.org/clo/le/platform/external/rincat/RTL88x2BU-Linux-Driver.git;protocol=https;branch=source/master \
    file://0001-adapt-makefile-to-support-KALAMA-Platform.patch \
    file://0001-adapt-upstream-driver-to-kp5.15.patch"

S = "${WORKDIR}/git"

KERNEL_VERSION = "${@get_kernelversion_file("${STAGING_KERNEL_BUILDDIR}")}"
EXT_MODULES = "${@os.path.relpath("${S}", "${KERNEL_PLATFORM_PATH}")}"

do_configure[noexec] = "1"

do_compile[depends]   += "virtual/kernel:do_shared_workdir"
do_compile[cleandirs] += "${WORKDIR}/out/${KERNEL_DEFCONFIG}"
do_compile() {
    cd ${KERNEL_PLATFORM_PATH}
    BUILD_CONFIG="msm-kernel/${KERNEL_CONFIG}" \
    EXT_MODULES=${EXT_MODULES} \
    ROOTDIR=${WORKDIR}/ \
    KERNEL_KIT=${KERNEL_PREBUILT_PATH} \
    OUT_DIR=${WORKDIR}/out/${KERNEL_DEFCONFIG} \
    INPLACE_COMPILE=y \
    ./build/build_module.sh
}

do_install() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra
    for i in $(find ${WORKDIR}/git . -name "*.ko"); do
        install -m 0755 ${i} -D ${D}/${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    done
}


FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/*"
