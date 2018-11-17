DESCRIPTION = "Hostap Daemon"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
${LICENSE};md5=3775480a712fc46a69647678acb234cb"

FILESEXTRAPATHS_prepend := "${WORKSPACE}:"

SRC_URI = "file://external/wpa_supplicant_8/ \
           file://defconfig \
           file://init \
          "
S = "${WORKDIR}/external/wpa_supplicant_8/hostapd"
B = "${WORKDIR}/external/wpa_supplicant_8/hostapd"

do_configure_prepend () {
    #Change defconfig file to configure specific features
    sed -i -e 's/^CONFIG_DRIVER_HOSTAP=y/#CONFIG_DRIVER_HOSTAP=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^CONFIG_DRIVER_WIRED=y/#CONFIG_DRIVER_WIRED=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^CONFIG_DRIVER_PRISM54=y/#CONFIG_DRIVER_PRISM54=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^CONFIG_RADIUS_SERVER=y/CONFIG_NO_RADIUS=y/g' ${WORKDIR}/defconfig
    sed -i -e 's/^CONFIG_DRIVER_RADIUS_ACL=y/#CONFIG_DRIVER_RADIUS_ACL=y/g' ${WORKDIR}/defconfig
    sed -i '$a\CONFIG_ACS=y' ${WORKDIR}/defconfig
    sed -i '$a\CONFIG_IEEE80211AC=y' ${WORKDIR}/defconfig
    sed -i '$a\CONFIG_IEEE80211W=y' ${WORKDIR}/defconfig
    sed -i '$a\CONFIG_INTERWORKING=y' ${WORKDIR}/defconfig
}
