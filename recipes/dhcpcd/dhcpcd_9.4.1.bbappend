FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:neo+= "file://0003-DHCP6-Improve-logging-when-changing-IA-type.patch"
SRC_URI:append:seraph += "file://0003-DHCP6-Improve-logging-when-changing-IA-type.patch"
