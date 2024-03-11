inherit autotools-brokensep linux-kernel-base pkgconfig

DESCRIPTION = "Wi-Fi Protected Access(WPA) Supplicant"
LICENSE = "BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=7a434440b651f4a472ca93716d01033a"

SOLIBS='*.so'
FILES_SOLIBSDEV=""

INC_PR = "r5"

DEPENDS = "openssl libnl dbus"

SRC_URI = "file://${WORKSPACE}/external/hostap"

S = "${WORKDIR}/hostap/wpa_supplicant"

do_install() {
    make install DESTDIR=${D} BINDIR=${sbindir} LIBDIR=${libdir} INCDIR=${includedir}
}
