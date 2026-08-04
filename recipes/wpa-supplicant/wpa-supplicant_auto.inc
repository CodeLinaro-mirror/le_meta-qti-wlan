DESCRIPTION = "Wi-Fi Protected Access(WPA) Supplicant used by auto"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

DEPENDS:remove = "qmi qmi-framework"
CONFFILES:${PN} += "${sysconfdir}/wpa_supplicant.conf"

SRC_URI += "file://wpa_supplicant.conf-sane"

do_configure:prepend () {
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

do_install:append () {
    install -d ${D}${docdir}/wpa_supplicant
    install -m 644 ${S}/wpa_supplicant.conf ${D}${docdir}/wpa_supplicant

    install -d ${D}${sysconfdir}
    install -m 600 ${WORKDIR}/wpa_supplicant.conf-sane ${D}${sysconfdir}/wpa_supplicant.conf
    install -d ${D}${includedir}/
    install -d ${D}${includedir}/utils
    install -d ${D}${includedir}/common
    install -d ${D}${includedir}/drivers
    install -d ${D}${includedir}/crypto
    install -d ${D}${includedir}/eap_peer
    install -d ${D}${includedir}/pasn
    install -d ${D}${includedir}/rsn_supp
    install -d ${D}${includedir}/ap
    install -d ${D}${includedir}/radius
    install -m 0644 ${S1}/src/drivers/*.h ${D}${includedir}/drivers/
    install -m 0644 ${S1}/src/utils/*.h ${D}${includedir}/utils/
    install -m 0644 ${S1}/src/utils/list.h ${D}${includedir}/common/
    install -m 0644 ${S1}/src/common/*.h ${D}${includedir}/common/
    install -m 0644 ${S1}/src/crypto/*.h ${D}${includedir}/crypto/
    install -m 0644 ${S1}/src/eap_peer/*.h ${D}${includedir}/eap_peer/
    install -m 0644 ${S1}/src/pasn/*.h ${D}${includedir}/pasn/
    install -m 0644 ${S1}/src/rsn_supp/pmksa_cache.h ${D}${includedir}/rsn_supp/
    install -m 0644 ${S1}/src/ap/pmksa_cache_auth.h ${D}${includedir}/ap/
    install -m 0644 ${S1}/src/radius/radius.h ${D}${includedir}/radius/
}

