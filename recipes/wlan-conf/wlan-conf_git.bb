inherit autotools systemd update-rc.d qperf useradd
DESCRIPTION = "Device specific config"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"
PR = "r3"

RDEPENDS_${PN} += "dhcpcd tcpdump ebtables iptables dnsmasq"
RDEPENDS_${PN}_append_sxr2130-mtp += "iperf2 iperf3"
FILESPATH =+ "${WORKSPACE}:"
# Provide a baseline
SRC_URI = "file://mdm-init/"
SRC_URI += "file://wlan_daemon.service"
SRC_URI += "file://cnss.service"
SRC_URI += "file://dhcpcd.service"
SRC_URI += "file://fi.w1.wpa_supplicant1.service"
SRC_URI += "file://dbus-wpa_supplicant.conf"
SRC_URI += "file://device/qcom/wlan/${SOC_FAMILY}/"
SRC_URI += "file://wlan-conf_systemd_tmpfiles.conf"

# Update for each machine
S = "${WORKDIR}/mdm-init/"

do_install_append_mdm(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		if grep -q "CONFIG_CNSS2=m" ${STAGING_KERNEL_BUILDDIR}/.config
		then
			install -d ${D}/etc/initscripts
			cp ${D}/etc/init.d/start_cnss_le ${D}/etc/initscripts/start_cnss_le
			install -d ${D}/etc/systemd/system/
			install -m 0644 ${WORKDIR}/cnss.service -D ${D}/etc/systemd/system/cnss.service
			install -d ${D}/etc/systemd/system/multi-user.target.wants/
			ln -sf /etc/systemd/system/cnss.service \
                                      ${D}/etc/systemd/system/multi-user.target.wants/cnss.service
			rm -rf ${D}/etc/init.d/start_cnss_le
		fi

		rm ${D}/etc/init.d/wlan
	fi
}

do_install_append_msm(){
  if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
      install -d ${D}/etc/initscripts
      cp ${D}/etc/init.d/wlan ${D}/etc/initscripts/wlan
      install -d ${D}/etc/systemd/system/
      install -d ${D}/etc/systemd/system/multi-user.target.wants/
    if ${@bb.utils.contains('BASEMACHINE', 'apq8009', bb.utils.contains('BASEPRODUCT', 'qsap', 'false', 'true', d), 'true', d)}; then
        install -m 0644 ${WORKDIR}/wlan_daemon.service -D ${D}/etc/systemd/system/wlan_daemon.service
        # enable the service for multi-user.target
        ln -sf /etc/systemd/system/wlan_daemon.service \
           ${D}/etc/systemd/system/multi-user.target.wants/wlan_daemon.service
    fi
  else
    if ${@bb.utils.contains('BASEMACHINE', 'apq8009', bb.utils.contains('BASEPRODUCT', 'qsap', 'false', 'true', d), 'true', d)}; then
        install -m 0755 ${S}/wlan_daemon -D ${D}${sysconfdir}/init.d/wlan_daemon
    fi
  fi
}

do_install_append_kona(){
  if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
      #systemd-tmpfiles service for wlan-conf
      install -d ${D}${sysconfdir}/tmpfiles.d
      install -m 0644 ${WORKDIR}/wlan-conf_systemd_tmpfiles.conf \
              -D ${D}${sysconfdir}/tmpfiles.d/wlan-conf_systemd_tmpfiles.conf
      install -d ${D}/etc/initscripts
      cp ${D}/etc/init.d/wlan ${D}/etc/initscripts/wlan
      install -d ${D}/etc/systemd/system/
      install -d ${D}/etc/systemd/system/multi-user.target.wants/
      install -m 0644 ${WORKDIR}/wlan_daemon.service -D ${D}/etc/systemd/system/wlan_daemon.service
      ln -sf /etc/systemd/system/wlan_daemon.service ${D}/etc/systemd/system/multi-user.target.wants/wlan_daemon.service
      install -m 0644 ${WORKDIR}/dhcpcd.service -D ${D}/etc/systemd/system/dhcpcd.service
      ln -sf /etc/systemd/system/dhcpcd.service ${D}/etc/systemd/system/multi-user.target.wants/dhcpcd.service
      install -m 0644 ${WORKDIR}/fi.w1.wpa_supplicant1.service -D ${D}/usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service
      install -m 0644 ${WORKDIR}/dbus-wpa_supplicant.conf -D ${D}/usr/share/dbus-1/system.d/dbus-wpa_supplicant.conf
  else
      install -m 0755 ${S}/wlan_daemon -D ${D}${sysconfdir}/init.d/wlan_daemon
  fi
}

FILES_${PN} += "/usr/share/dbus-1/system-services/*"
FILES_${PN} += "/usr/share/dbus-1/system.d/*"

do_install_append_sxr2130(){
      if [ -e "${WORKDIR}/device/qcom/wlan/${SOC_FAMILY}/WCNSS_qcom_cfg_qca6490.ini" ];then
            install -m 0644 ${WORKDIR}/device/qcom/wlan/${SOC_FAMILY}/WCNSS_qcom_cfg_qca6490.ini ${D}/lib/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini
      fi
}

FILES_${PN} += "${userfsdatadir}/misc/wifi/*"
FILES_${PN} += "${base_libdir}/firmware/wlan/qca_cld/*"
FILES_${PN} += "/lib/firmware/wlan/qca_cld/* ${sysconfdir}/init.d/* "
FILES_${PN} += "/data/*"

BASEPRODUCT = "${@d.getVar('PRODUCT', False)}"

EXTRA_OECONF_append = " --enable-target-${BASEMACHINE}="yes""
EXTRA_OECONF_append_qcs40x = " --enable-target-qcs405-som1=yes"
EXTRA_OECONF_append_apq8053 = " --enable-pronto-wlan=yes"
EXTRA_OECONF_append_apq8017 = " --enable-pronto-wlan=yes"
EXTRA_OECONF_append_kona = " --enable-target-qrb5165=yes"

# Enable qsap-wlan in place of pronto-wlan for Drones
EXTRA_OECONF_append_qsap += "--enable-snap-wlan=yes --enable-qsap-wlan=yes --enable-naples-wlan=yes"

# Enable drone-wlan in place of pronto-wlan for Drones
EXTRA_OECONF_append_drone += "'--enable-drone-wlan=yes"

# Enable robot-wlan according to variants
EXTRA_OECONF_append_robot-som += "--enable-robot-som-wlan=yes"
EXTRA_OECONF_remove_robot-rome += "--enable-robot-som-wlan=yes"
EXTRA_OECONF_append_robot-rome += "--enable-robot-wlan=yes"
EXTRA_OECONF_remove_robot-pronto += "--enable-robot-som-wlan=yes"
EXTRA_OECONF_append_robot-pronto += "--enable-pronto-wlan=yes"

INITSCRIPT_NAME   = "wlan_daemon"
INITSCRIPT_PARAMS = "remove"
INITSCRIPT_PARAMS_apq8009 = "${@bb.utils.contains('BASEPRODUCT', 'drone', 'start 01 2 3 4 5 . stop 2 0 1 6 .', 'start 98 5 . stop 2 0 1 6 .', d)}"
INITSCRIPT_PARAMS_apq8053 = "start 98 5 . stop 2 0 1 6 ."
INITSCRIPT_PARAMS_apq8017 = "start 98 5 . stop 2 0 1 6 ."
INITSCRIPT_PARAMS_apq8096 = "${@bb.utils.contains('BASEPRODUCT', 'drone', 'start 01 2 3 4 5 . stop 2 0 1 6 .', 'start 98 5 . stop 2 0 1 6 .', d)}"
