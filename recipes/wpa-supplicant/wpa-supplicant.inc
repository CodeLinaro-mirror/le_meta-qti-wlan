inherit autotools-brokensep linux-kernel-base pkgconfig

DESCRIPTION = "Wi-Fi Protected Access(WPA) Supplicant"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=3775480a712fc46a69647678acb234cb"

SOLIBS='*.so'
FILES_SOLIBSDEV=""

INC_PR = "r5"

DEPENDS = "openssl libnl"

SRC_URI = "file://${WORKSPACE}/external/hostap"

S = "${WORKDIR}/hostap/wpa_supplicant"

do_install() {
    if [ ${BASEMACHINE} == "sdxlemur" ]; then
        make install DESTDIR=${D} BINDIR=${sbindir}/mcc LIBDIR=${libdir} INCDIR=${includedir}
        ln -sf /systemrw/wlan/bin/wpa_supplicant ${D}/usr/sbin/wpa_supplicant
        ln -sf /systemrw/wlan/bin/wpa_cli ${D}/usr/sbin/wpa_cli
    else
        make install DESTDIR=${D} BINDIR=${sbindir} LIBDIR=${libdir} INCDIR=${includedir}
    fi
}
