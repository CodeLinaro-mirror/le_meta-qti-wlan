DESCRIPTION = "Device specific config"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r0"

FILES_${PN} += "lib/firmware/wlan/*"
FILESPATH =+ "${WORKSPACE}:"
# Provide a baseline
SRC_URI = "file://device/"
SRC_URI =+ "file://mdm-init/"

# Update for each machine
S = "${WORKDIR}/device"

do_install_append_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}/usr/bin
	install -m 0755 ${S}/qcom/wlan/sdx_auto/*.sh ${D}/usr/bin
}

do_install_append_mdm9607_mdm(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${WORKDIR}/mdm-init/wlan_sdio/*.conf ${D}/etc/misc/wifi
	install -d ${D}/usr/bin
	install -m 0755 ${WORKDIR}/mdm-init/wlan_sdio/*.sh ${D}/usr/bin
	install -d ${D}/lib/firmware/wlan/qca_cld
	install -m 0644 ${WORKDIR}/mdm-init/wlan_sdio/*.ini ${D}/lib/firmware/wlan/qca_cld
}

