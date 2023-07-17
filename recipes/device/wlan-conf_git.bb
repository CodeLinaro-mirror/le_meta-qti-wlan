DESCRIPTION = "Device specific config"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r0"

FILESPATH =+ "${WORKSPACE}:"
FILES_${PN} += "lib/firmware/wlan/*"
FIRMWARE_PATH = "${D}/lib/firmware/wlan/qca_cld/qca6490"
FIRMWARE_PATH_ROME = "${D}/lib/firmware/wlan/qca_cld/qca6574"

# Provide a baseline
SRC_URI = "file://device/"

# Update for each machine
S = "${WORKDIR}/device"

do_install_append_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}/usr/bin
	install -m 0755 ${S}/qcom/wlan/sdx_auto/*.sh ${D}/usr/bin
}

do_install_append_sa410m(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${FIRMWARE_PATH_ROME}
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qca6174.ini ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
}

do_install_append_sa525m(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${FIRMWARE_PATH}
	install -d ${FIRMWARE_PATH_ROME}
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qca6174.ini ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6490.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_install_append_sa415m_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}/usr/bin
	install -m 0755 ${S}/qcom/wlan/sdx24_auto/*.sh ${D}/usr/bin
}

do_install_append_sa515m_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}${sysconfdir}
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/vendor_cmd.xml ${D}${sysconfdir}
}

do_install_append_sa515m(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}${sysconfdir}
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/vendor_cmd.xml ${D}${sysconfdir}
	install -d ${FIRMWARE_PATH}
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6490.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}

do_install_append_sa415m(){
        install -d ${D}/etc/misc/wifi
        install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
        install -d ${D}${sysconfdir}
        install -m 0644 ${S}/qcom/wlan/sdx24_auto/vendor_cmd.xml ${D}${sysconfdir}
        install -d ${FIRMWARE_PATH}
        install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6490.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
        chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}
