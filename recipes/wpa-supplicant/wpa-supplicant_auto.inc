DESCRIPTION = "Wi-Fi Protected Access(WPA) Supplicant used by auto"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=3775480a712fc46a69647678acb234cb"

DEPENDS_remove = "qmi qmi-framework"
CONFFILES_${PN} += "${sysconfdir}/wpa_supplicant.conf"

SRC_URI += "file://wpa_supplicant.conf-sane"

do_configure_prepend () {
    sed -i -e 's/^CONFIG_EAP_PROXY=qmi/#CONFIG_EAP_PROXY=qmi/g' ${WORKDIR}/defconfig-qcacld
    sed -i -e 's/^CONFIG_EAP_PROXY_DUAL_SIM := true/#CONFIG_EAP_PROXY_DUAL_SIM := true/g' ${WORKDIR}/defconfig-qcacld
    sed -i -e 's/^CONFIG_EAP_PROXY_AKA_PRIME := true/#CONFIG_EAP_PROXY_AKA_PRIME := true/g' ${WORKDIR}/defconfig-qcacld
    #enable CONFIG_WNM
    if (( `grep -c "^CONFIG_WNM=y" ${WORKDIR}/defconfig-qcacld` )); then
        break
    elif (( `grep -c "^#CONFIG_WNM=y" ${WORKDIR}/defconfig-qcacld` )); then
        sed -i -e 's/^#CONFIG_WNM=y/CONFIG_WNM=y/g' ${WORKDIR}/defconfig-qcacld
    else
        sed -i '$a\CONFIG_WNM=y' ${WORKDIR}/defconfig-qcacld
    fi

    #enable CONFIG_WIFI_DISPLAY
    if (( `grep -c "^CONFIG_WIFI_DISPLAY=y" ${WORKDIR}/defconfig-qcacld` )); then
        break
    elif (( `grep -c "^#CONFIG_WIFI_DISPLAY=y" ${WORKDIR}/defconfig-qcacld` )); then
        sed -i -e 's/^#CONFIG_WIFI_DISPLAY=y/CONFIG_WIFI_DISPLAY=y/g' ${WORKDIR}/defconfig-qcacld
    else
        sed -i '$a\CONFIG_WIFI_DISPLAY=y' ${WORKDIR}/defconfig-qcacld
    fi
}

do_install_append () {
    install -d ${D}${docdir}/wpa_supplicant
    install -m 644 ${S}/wpa_supplicant.conf ${D}${docdir}/wpa_supplicant

    install -d ${D}${sysconfdir}
    install -m 600 ${WORKDIR}/wpa_supplicant.conf-sane ${D}${sysconfdir}/wpa_supplicant.conf
}

