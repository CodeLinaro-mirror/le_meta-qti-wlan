inherit autotools-brokensep pkgconfig

DESCRIPTION = "WFA certification testing tool for QCA devices"
HOMEPAGE = "https://github.com/qca/sigma-dut"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"
PV = "1.0"
PR = "r0"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/utils/sigma-dut/"
PACKAGE_ARCH ?= "${MACHINE_ARCH}"

SRC_DIR = "${WORKSPACE}/wlan/utils/sigma-dut/"

DEPENDS = "libnl"

CFLAGS += "-DLINUX_EMBEDDED"
CFLAGS += "-I ${STAGING_INCDIR}/libnl3"

S = "${WORKDIR}/wlan/utils/sigma-dut"

do_patch() {
    cd ${S}
    mkdir ${WORKDIR}/files/
    cp ${COREBASE}/meta-qti-wlan/recipes/wlan-sigma-dut/files/*.patch ${WORKDIR}/files/
    for patch in ${WORKDIR}/files/*.patch; do
        patch -p1 < "$patch"
    done
}

do_install() {
    if [ ${BASEMACHINE} == "sdxlemur" ]; then
        make install DESTDIR=${D} BINDIR=${sbindir}/mcc
        ln -sf /systemrw/wlan/bin/sigma_dut ${D}/usr/sbin/sigma_dut
    else
        make install DESTDIR=${D} BINDIR=${sbindir}/
    fi
}
