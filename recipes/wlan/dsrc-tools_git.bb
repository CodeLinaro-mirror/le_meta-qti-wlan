inherit autotools

SUMMARY = "Qualcomm Atheros WLAN DSRC TOOLS"
DESCRIPTION = "The wlan dsrc tools are the application softwares with the aim of \
doing the dsrc configuration and related tx/rx test."

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

DEPENDS = "libnl"

PR = "r1"
PV = "1.0"

PACKAGE_ARCH ?= "${MACHINE_ARCH}"

FILESPATH =+ "${WORKSPACE}:"
SRC_URI = "file://wlan/tools/ \
          "
S = "${WORKDIR}/wlan/tools"

CFLAGS += "-I${STAGING_INCDIR}/libnl3"
CFLAGS += "-Wall -Wno-error=deprecated-declarations -Wno-error=format-truncation"

EXTRA_OEMAKE = "HAVE_LIBNL3=1 all dsrc_config wlan_ts"

do_compile_prepend() {
    cd ${S}/dsrc
}

do_install() {
    install -d ${D}${sbindir}/
    install -d ${D}${libdir}/
    install -d ${D}${includedir}/dsrc-tools/
    install -m 0755 ${S}/dsrc/inc/* ${D}${includedir}/dsrc-tools/
    install -m 0755 ${S}/dsrc/src/*.h ${D}${includedir}/dsrc-tools/
    install -m 0755 ${S}/dsrc/lib/* ${D}${libdir}/
    install -m 0755 ${S}/dsrc/bin/dsrc_* ${D}${sbindir}/
    install -m 0755 ${S}/dsrc/bin/wlan_ts ${D}${sbindir}/
    install -m 0755 ${S}/dsrc/bin/dcc.dat ${D}${sbindir}/
}

INSANE_SKIP_${PN} = "dev-elf"
INSANE_SKIP_${PN} = "ldflags"
INSANE_SKIP_${PN}-dev = "ldflags"

SOLIBS = ".so"
FILES_SOLIBSDEV = ""
FILES_${PN} += "${libdir}/*"
FILES_${PN} += "${userfsdatadir}/*"
FILES_${PN} += "${includedir}"
FILES_${PN} += "${includedir}/dsrc-tools"
FILES_${PN} += "${sbindir}"
