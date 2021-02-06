SUMMARY = "Tools for Linux Standard Wireless Extension Subsystem"
HOMEPAGE = "https://hewlettpackard.github.io/wireless-tools/Tools.html"
LICENSE = "GPLv2 & (LGPLv2.1 | MPL-1.1 | BSD)"
LIC_FILES_CHKSUM = "file://COPYING;md5=94d55d512a9ba36caa9b7df079bae19f"
SECTION = "base"

SRC_URI = "https://hewlettpackard.github.io/wireless-tools/wireless_tools.${PV}.tar.gz"
SRC_URI[md5sum] = "e06c222e186f7cc013fd272d023710cb"
SRC_URI[sha256sum] = "6fb80935fe208538131ce2c4178221bab1078a1656306bce8909c19887e2e5a1"

S = "${WORKDIR}/wireless_tools.${PV}"

EXTRA_OEMAKE = "-e 'BUILD_SHARED=y' \
		'INSTALL_DIR=${D}${base_sbindir}' \
		'INSTALL_LIB=${D}${libdir}'"

do_install() {
	oe_runmake PREFIX=${D} install-iwmulticall install-dynamic
	install -d ${D}${sbindir}
}
