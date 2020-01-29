inherit autotools qcommon

DESCRIPTION = "WFA certification testing tool for QCA devices"
HOMEPAGE = "https://github.com/qca/sigma-dut"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r0"

SRC_DIR = "${WORKSPACE}/wlan/utils/sigma-dut/"
SRC_URI += "file://updated-dhcpcd-dnsmasq-path-for-P2P-interf.patch"

CFLAGS += "-DLINUX_EMBEDDED"

S = "${WORKDIR}/wlan/utils/sigma-dut"
PATCH_DIR = "${WORKDIR}/wlan/utils/sigma-dut"

do_patch() {
	cd ${PATCH_DIR}
	patch -p1 < ${WORKDIR}/updated-dhcpcd-dnsmasq-path-for-P2P-interf.patch
}

do_install() {
    make install DESTDIR=${D} BINDIR=${sbindir}/
}
