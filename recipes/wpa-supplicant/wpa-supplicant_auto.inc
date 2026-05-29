DESCRIPTION = "Wi-Fi Protected Access(WPA) Supplicant used by auto"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

DEPENDS:remove = "qmi qmi-framework"
CONFFILES:${PN} += "${sysconfdir}/wpa_supplicant.conf"

SRC_URI += "file://wpa_supplicant.conf-sane"

do_configure:prepend () {
    sed -i -e 's/^CONFIG_EAP_PROXY=qmi/#CONFIG_EAP_PROXY=qmi/g' ${UNPACKDIR}/defconfig-qcacld
    sed -i -e 's/^CONFIG_EAP_PROXY_DUAL_SIM := true/#CONFIG_EAP_PROXY_DUAL_SIM := true/g' ${UNPACKDIR}/defconfig-qcacld
    sed -i -e 's/^CONFIG_EAP_PROXY_AKA_PRIME := true/#CONFIG_EAP_PROXY_AKA_PRIME := true/g' ${UNPACKDIR}/defconfig-qcacld
    #enable CONFIG_WNM
    if (( `grep -c "^CONFIG_WNM=y" ${UNPACKDIR}/defconfig-qcacld` )); then
        break
    elif (( `grep -c "^#CONFIG_WNM=y" ${UNPACKDIR}/defconfig-qcacld` )); then
        sed -i -e 's/^#CONFIG_WNM=y/CONFIG_WNM=y/g' ${UNPACKDIR}/defconfig-qcacld
    else
        sed -i '$a\CONFIG_WNM=y' ${UNPACKDIR}/defconfig-qcacld
    fi

    #enable CONFIG_WIFI_DISPLAY
    if (( `grep -c "^CONFIG_WIFI_DISPLAY=y" ${UNPACKDIR}/defconfig-qcacld` )); then
        break
    elif (( `grep -c "^#CONFIG_WIFI_DISPLAY=y" ${UNPACKDIR}/defconfig-qcacld` )); then
        sed -i -e 's/^#CONFIG_WIFI_DISPLAY=y/CONFIG_WIFI_DISPLAY=y/g' ${UNPACKDIR}/defconfig-qcacld
    else
        sed -i '$a\CONFIG_WIFI_DISPLAY=y' ${UNPACKDIR}/defconfig-qcacld
    fi
}

do_install:append () {
    install -d ${D}${docdir}/wpa_supplicant
    install -m 644 ${S}/wpa_supplicant.conf ${D}${docdir}/wpa_supplicant

    install -d ${D}${sysconfdir}
    install -m 600 ${UNPACKDIR}/wpa_supplicant.conf-sane ${D}${sysconfdir}/wpa_supplicant.conf
}

