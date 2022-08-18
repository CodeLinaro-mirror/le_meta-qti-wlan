inherit autotools-brokensep pkgconfig

DESCRIPTION = "WFA certification testing tool for QCA devices"
DEPENDS = "libnl"
HOMEPAGE = "https://github.com/qca/sigma-dut"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r0"

SRC_DIR = "${WORKSPACE}/wlan/utils/sigma-dut/"

S = "${WORKDIR}/wlan/utils/sigma-dut"

CFLAGS += "-I${STAGING_INCDIR}/libnl3/"

EXTRA_OEMAKE += "NL80211_SUPPORT=y"

do_install() {
    make install DESTDIR=${D} BINDIR=${sbindir}/
}
