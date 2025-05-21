inherit useradd
DESCRIPTION = "Device specific config"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r0"

FILESPATH =+ "${WORKSPACE}:"
FILES:${PN} += "lib/firmware/wlan/*"
FILES:${PN} += "/data/qca6490/*"
FILES:${PN} += "/data/qca6574/*"
FILES:${PN} += "/data/qca6797/*"
FIRMWARE_PATH_HSP = "${D}/lib/firmware/wlan/qca_cld/qca6490"
FIRMWARE_PATH_HMT = "${D}/lib/firmware/wlan/qca_cld/qca6797"
FIRMWARE_PATH_ROME = "${D}/lib/firmware/wlan/qca_cld/qca6574"
FIRMWARE_PATH_ROME:sa510m = "${D}/usr/lib/firmware/wlan/qca_cld/qca6574"
FIRMWARE_PATH_HSP:sa510m = "${D}/usr/lib/firmware/wlan/qca_cld/qca6490"
FILES:${PN}:sa510m += "/usr/lib/firmware/wlan/*"
FILES:${PN}:sa510m += "/etc/misc/wifi"

# Provide a baseline
SRC_URI = "file://device/"

# Update for each machine
S = "${WORKDIR}/device"

do_install:append:auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}/usr/bin
	install -m 0755 ${S}/qcom/wlan/sdx_auto/*.sh ${D}/usr/bin
}

do_install:append:sa410m(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${FIRMWARE_PATH_ROME}
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx24_auto/WCNSS_qcom_cfg_qca6174.ini ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
}

do_install:append:sa525m(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx_auto/*.conf ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/msm_auto/hostapd_mlo*.conf ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/msm_auto/hostapd_11be*.conf ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/msm_auto/udhcpd.conf ${D}/etc/misc/wifi
	chown -R radio:radio ${D}/etc/misc/wifi
	install -d ${FIRMWARE_PATH_HSP}
	install -d ${FIRMWARE_PATH_ROME}
	install -d ${FIRMWARE_PATH_HMT}
	install -d ${D}/data/qca6574
	install -d ${D}/data/qca6490
	install -d ${D}/data/qca6797
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6174.ini ${D}/data/qca6574/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${D}/data/qca6574/WCNSS_qcom_cfg.ini
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6490.ini ${D}/data/qca6490/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${D}/data/qca6490/WCNSS_qcom_cfg.ini
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6797.ini ${D}/data/qca6797/WCNSS_qcom_cfg.ini
        chmod -R 0664 ${D}/data/qca6797/WCNSS_qcom_cfg.ini
        ln -sf /data/qca6574/WCNSS_qcom_cfg.ini ${FIRMWARE_PATH_ROME}/
        ln -sf /data/qca6490/WCNSS_qcom_cfg.ini ${FIRMWARE_PATH_HSP}/
        ln -sf /data/qca6797/WCNSS_qcom_cfg.ini ${FIRMWARE_PATH_HMT}/
}

do_install:append:sa415m_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}/usr/bin
	install -m 0755 ${S}/qcom/wlan/sdx24_auto/*.sh ${D}/usr/bin
}

do_install:append:sa515m_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}${sysconfdir}
	install -m 0644 ${S}/qcom/wlan/sdx_auto/vendor_cmd.xml ${D}${sysconfdir}
}

do_install:append:sa515m(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}${sysconfdir}
	install -m 0644 ${S}/qcom/wlan/sdx_auto/vendor_cmd.xml ${D}${sysconfdir}
	install -d ${FIRMWARE_PATH}
	install -D -m 0644 ${WORKDIR}/device/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6490.ini ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
	chmod -R 0664 ${FIRMWARE_PATH}/WCNSS_qcom_cfg.ini
}
do_install:append:sa510m(){
        install -d ${D}/etc/misc/wifi
        install -m 0644 ${S}/qcom/wlan/sdx_auto/*.conf ${D}/etc/misc/wifi
        install -d ${FIRMWARE_PATH_ROME}
        install -D -m 0644 ${S}/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6174.ini ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
        chmod -R 0664 ${FIRMWARE_PATH_ROME}/WCNSS_qcom_cfg.ini
        install -d ${FIRMWARE_PATH_HSP}
        install -D -m 0644 ${S}/qcom/wlan/sdx_auto/WCNSS_qcom_cfg_qca6490.ini ${FIRMWARE_PATH_HSP}/WCNSS_qcom_cfg.ini
        chmod -R 0664 ${FIRMWARE_PATH_HSP}/WCNSS_qcom_cfg.ini
}
