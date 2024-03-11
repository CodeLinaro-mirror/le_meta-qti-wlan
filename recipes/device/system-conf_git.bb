inherit autotools pkgconfig

DESCRIPTION = "Device specific config"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"
PR = "r3"

FILESPATH =+ "${WORKSPACE}:"
# Provide a baseline
SRC_URI = "file://mdm-init/"


# Update for each machine
S = "${WORKDIR}/mdm-init/"

FILES:${PN} += "${userfsdatadir}/misc/wifi/*"
#FILES:${PN} += "${base_libdir}/firmware/wlan/qca_cld/*"
#FILES:${PN} += "${nonarch_base_libdir}/firmware/wlan/qca_cld/* ${sysconfdir}/init.d/* "

BASEPRODUCT = "${@d.getVar('PRODUCT', False)}"

EXTRA_OECONF += "--enable-target-mdm9607=yes"

do_install:append() {
    #create /data/misc/wifi/ folder
    install -d ${D}${userfsdatadir}/misc/wifi/

    if [ -f ${S}wlan_sdio/hostapd.conf ]; then
           install -m 0660 ${S}wlan_sdio/hostapd.conf ${D}${userfsdatadir}/misc/wifi/
    fi
}

