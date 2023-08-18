SUMMARY = "gn"
HOMEPAGE = "https://gn.googlesource.com/gn/"
DESCRIPTION = "Supporting gn tool on QCS610 for Matter standard."
SECTION = "base"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

BRANCH = "master"
SRC_URI = "git://gn.googlesource.com/gn.git;branch=${BRANCH};protocol=https"
SRCREV = "fe330c0ae1ec29db30b6f830e50771a335e071fb"
SRC_URI[md5sum] = "9a28108dcc21f8e7d9deed43678beb81"

SRC_URI += " file://gn_build.patch "

S = "${WORKDIR}/git"

DEPENDS += "ninja-native"

#TARGET_CC = "${CC}"
#TARGET_CXX = "${CXX}"

do_configure() {
    export CC=gcc
    export CXX=g++
    cd ${S}/
    python3 build/gen.py --out-path=${S}/out
}

do_compile() {
    export CC=gcc
    export CXX=g++
    cd ${S}/
    ninja -C out

}

do_install() {
    install -d -m 755 ${D}${sbindir}
    install ${S}/out/gn ${D}${sbindir}
}
BBCLASSEXTEND = "native nativesdk"
