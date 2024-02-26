inherit autotools-brokensep linux-kernel-base pkgconfig

DESCRIPTION = "Hostap Daemon"
LICENSE = "BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=7a434440b651f4a472ca93716d01033a"

FILES:${PN} += "\
        /usr/bin \
        "
INC_PR = "r4"

DEPENDS = "openssl libnl"

SRC_URI = "file://${WORKSPACE}/external/hostap/"

S = "${WORKDIR}/external/hostap/hostapd/"

do_install() {
    make install DESTDIR=${D} BINDIR=${sbindir}/
}
