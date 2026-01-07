DESCRIPTION = "wlan-uci"
LICENSE = "BSD-3-Clause-Clear"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta-qti-bsp/files/common-licenses/${LICENSE};md5=3771d4920bd6cdb8cbdf1e8344489ee0"

FILES_${PN} += "/lib/wifi_mcc/* /sbin/*"
FILES_${PN} += "/data/vendor/wifi/default_config/*"

do_install_append_sdxlemur() {
	install -m 0755 -d ${D}/lib/wifi_mcc
	install -m 0755 -d ${D}/etc/misc/wifi
	install -m 0755 -d ${D}/etc/config/default_wifi_configs
	install -m 0755 -d ${D}/usr/sbin
	install -m 0755 -d ${D}/usr/sbin/mcc
	install -m 0755 -d ${D}/sbin/
	install -m 0755 -d ${D}/data/vendor/wifi/default_config

	install -m 0755 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/qcacld32.sh ${D}/lib/wifi_mcc/
	install -m 0755 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/qcacld32-utils.sh ${D}/lib/wifi_mcc/
	install -m 0755 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/hostapd.sh ${D}/lib/wifi_mcc/
	install -m 0755 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/wpa_supplicant.sh ${D}/lib/wifi_mcc/
	install -m 0755 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/sdxlemur/qcacld32-modules ${D}/lib/wifi_mcc/

	install -m 0666 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/wireless \
		${D}/data/vendor/wifi/default_config/

	install -m 0666 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/sdxlemur/2g_wireless ${D}/etc/misc/wifi/
	install -m 0666 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/sdxlemur/5g_wireless ${D}/etc/misc/wifi/
	ln -sf /systemrw/wlan/config/2g_wireless ${D}/etc/config/default_wifi_configs/2g_wireless
	ln -sf /systemrw/wlan/config/5g_wireless ${D}/etc/config/default_wifi_configs/5g_wireless

	install -m 0755 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/ucitool ${D}/usr/sbin/mcc/
	ln -sf /systemrw/wlan/bin/ucitool ${D}/usr/sbin/ucitool

	install -m 0755 ${COREBASE}/meta-qti-wlan/feeds/wlan-uci/files/sdxlemur/wifi ${D}/usr/sbin/mcc/
	ln -sf /systemrw/wlan/bin/wifi ${D}/sbin/wifi
}
