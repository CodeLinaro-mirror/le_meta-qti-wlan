SUMMARY = "Matter Over Wifi"
HOMEPAGE = "https://github.com/project-chip/connectedhomeip"
DESCRIPTION = "Supporting Matter on QCS610."
SECTION = "base"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=89aea4e17d99a7cacdbeed46a0096b10"

BRANCH = "v1.0-branch"
SRC_URI = "gitsm://github.com/project-chip/connectedhomeip.git;branch=${BRANCH};protocol=https"
SRCREV = "v1.0.0"
SRC_URI[md5sum] = "d99b3661674e0901bdb26675a0a1e717"
SRC_URI[sha256sum] = "0d289e85f56e734149597f8c5346cdaa494002158fa102c4149b891f075dcaec"

SRC_URI += " file://activiate.patch \
             file://environment.patch"

S = "${WORKDIR}/git"

DEPENDS += " avahi ninja-native dbus-glib-native "

TARGET_CC = "${CC}"
TARGET_CXX = "${CXX}"
PY3_PATH = "/pkg/qct/software/ubuntu/python/3.8.2/bin"

do_configure() {
    export PATH=${PY3_PATH}:${PATH}
    export CC=gcc
    export CXX=g++

    cd ${S}
    source scripts/activate.sh

    cd ${S}/examples/all-clusters-app/linux
    gn gen out/test --args='is_debug=false treat_warnings_as_errors=false target_os="linux" target_cpu="arm64" custom_toolchain="${S}/build/toolchain/custom" target_cc="${TARGET_CC}" target_cxx="${TARGET_CXX}" target_ar="${AR}"'

    cd ${S}/examples/chip-tool
    gn gen out/test --args='is_debug=false treat_warnings_as_errors=false target_os="linux" target_cpu="arm64" custom_toolchain="${S}/build/toolchain/custom" target_cc="${TARGET_CC}" target_cxx="${TARGET_CXX}" target_ar="${AR}"'
}

do_compile() {

    cd ${S}/examples/all-clusters-app/linux/out/test
    python3 ${THISDIR}/files/rspfile.py toolchain.ninja ${S}
    cd ${S}/examples/all-clusters-app/linux
    ninja -C out/test

    cd ${S}/examples/chip-tool/out/test
    python3 ${THISDIR}/files/rspfile.py toolchain.ninja ${S}
    cd ${S}/examples/chip-tool
    ninja -C out/test
}

do_install() {
    install -d -m 755 ${D}${sbindir}
    install ${S}/examples/all-clusters-app/linux/out/test/chip-all-clusters-app ${D}${sbindir}
    install ${S}/examples/chip-tool/out/test/chip-tool ${D}${sbindir}
}
#BBCLASSEXTEND = "native nativesdk"
