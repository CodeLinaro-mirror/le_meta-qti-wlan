DESCRIPTION = "Device specific config"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r0"

FILESPATH =+ "${WORKSPACE}:"
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

do_install_append_sa415m_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
	install -d ${D}/usr/bin
	install -m 0755 ${S}/qcom/wlan/sdx24_auto/*.sh ${D}/usr/bin
        if ${@bb.utils.contains('DISTRO_FEATURES','nand-squashfs','true','false',d)}; then
            install -d ${D}${userfsdatadir}/misc/wifi
            install -m 0664 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}${userfsdatadir}/misc/wifi
            ln -sf /data/misc/wifi/wpa_supplicant.conf  ${D}/etc/misc/wifi/wpa_supplicant.conf
        fi
}

do_install_append_sa515m_auto(){
	install -d ${D}/etc/misc/wifi
	install -m 0644 ${S}/qcom/wlan/sdx24_auto/*.conf ${D}/etc/misc/wifi
}
