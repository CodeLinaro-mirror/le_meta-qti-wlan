inherit autotools-brokensep linux-kernel-base pkgconfig

DESCRIPTION = "Wi-Fi Protected Access(WPA) Supplicant"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

SOLIBS='*.so'
FILES_SOLIBSDEV=""

INC_PR = "r5"

DEPENDS = "openssl libnl dbus"

SRC_URI = "file://${WORKSPACE}/external/hostap"

S = "${UNPACKDIR}/hostap/wpa_supplicant"

do_install() {
    make install DESTDIR=${D} BINDIR=${sbindir} LIBDIR=${libdir} INCDIR=${includedir}
}
