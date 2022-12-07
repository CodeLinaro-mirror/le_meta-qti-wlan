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

SRC_URI += " file://connectivity-fix.patch \
             file://activiate.patch \
             file://python_json.patch \
             file://update-python-dependencies.patch \
             file://add-platform-qcs610-in-Matter.patch \
             file://environment.patch"

S = "${WORKDIR}/git"

DEPENDS += "avahi ninja-native dbus-glib-native libbsd glib-2.0 libchrome fluoride bt-app btobex"

TARGET_CC = "${CC}"
TARGET_CXX = "${CXX}"

do_configure() {
    export CC=gcc
    export CXX=g++

    python3 ${THISDIR}/files/generateQcs610.py ${S} ${THISDIR}/files/ ${WORKSPACE}

    cd ${S}
    source scripts/activate.sh

    cd ${S}/examples/all-clusters-app/qcs610
    gn gen -v out/test --args='is_debug=false treat_warnings_as_errors=false chip_device_platform="qcs610" target_os="linux" target_cpu="arm64" custom_toolchain="${S}/build/toolchain/custom" target_cc="${TARGET_CC}" target_cxx="${TARGET_CXX}" target_ar="${AR}" qcs610_bt_root="${WORKSPACE}" qcs610_sdk="${STAGING_INCDIR}" '
}

do_compile() {

    cd ${S}/examples/all-clusters-app/qcs610/out/test
    python3 ${THISDIR}/files/rspfile.py toolchain.ninja ${S}
    cd ${S}/examples/all-clusters-app/qcs610
    ninja -C out/test

}

do_install() {
    install -d -m 755 ${D}${sbindir}
    install ${S}/examples/all-clusters-app/qcs610/out/test/chip-all-clusters-app ${D}${sbindir}
}
#BBCLASSEXTEND = "native nativesdk"
