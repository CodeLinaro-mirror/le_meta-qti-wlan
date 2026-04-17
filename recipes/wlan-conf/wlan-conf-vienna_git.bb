inherit systemd
DESCRIPTION = "WLAN Daemon Service to bringup wifi."
LICENSE = "BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/BSD-3-Clause-Clear;md5=7a434440b651f4a472ca93716d01033a"
PV = "1.0"
PR = "r1"

FILESPATH =+ "${WORKSPACE}:"
MACHINE_CONFIG = "${BASEMACHINE}"

# Provide a baseline
SRC_URI += "file://vienna/wlan_daemon.service"
SRC_URI += "file://vienna/wlan"
SRC_URI += "file://vienna/wpa_supplicant.conf"

SYSTEMD_SERVICE:${PN} = "wlan_daemon.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install(){
    # Install script into /usr/sbin
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/vienna/wlan ${D}${sbindir}/wlan

    # Install daemon to systemd service file
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/vienna/wlan_daemon.service ${D}${systemd_system_unitdir}/wlan_daemon.service

    # Install dummy wpa_supplicant.conf for reference
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/vienna/wpa_supplicant.conf ${D}${sysconfdir}
}

FILES:${PN} += "${sbindir}/wlan"
FILES:${PN} += "${systemd_system_unitdir}/wlan_daemon.service"
FILES:${PN} += "${sysconfdir}/wpa_supplicant.conf"
