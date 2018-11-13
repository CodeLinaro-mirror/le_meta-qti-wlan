DESCRIPTION = "Wi-Fi Protected Access(WPA) Supplicant"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=3775480a712fc46a69647678acb234cb"

FILESEXTRAPATHS_prepend := "${WORKSPACE}:"
SRC_URI = "file://external/wpa_supplicant_8/ \
           file://defconfig \
           file://wpa-supplicant.sh \
           file://wpa_supplicant.conf \
           file://wpa_supplicant.conf-sane \
           file://99_wpa_supplicant \
          "
S = "${WORKDIR}/external/wpa_supplicant_8"

do_configure_prepend () {
    #Change defconfig file to configure specific features
    sed -i -e 's/^CONFIG_DRIVER_HOSTAP=y/#CONFIG_DRIVER_HOSTAP=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_IEEE80211W=y/CONFIG_IEEE80211W=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_CTRL_IFACE_DBUS_INTRO=y/CONFIG_CTRL_IFACE_DBUS_INTRO=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_IEEE80211N=y/CONFIG_IEEE80211N=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_IEEE80211AC=y/CONFIG_IEEE80211AC=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_WNM=y/CONFIG_WNM=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_P2P=y/CONFIG_P2P=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_TDLS=y/CONFIG_TDLS=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_WIFI_DISPLAY=y/CONFIG_WIFI_DISPLAY=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^#CONFIG_READLINE=y/CONFIG_READLINE=y/g' ${WORKDIR}/defconfig
}