inherit autotools systemd update-rc.d qperf useradd
DESCRIPTION = "Device specific config"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"
PV = "1.0"
PR = "r3"
DEPENDS += "virtual/kernel"

FILESPATH =+ "${WORKSPACE}:"
# Provide a baseline
SRC_URI = "file://mdm-init/"
SRC_URI += "file://wlan_daemon.service"
SRC_URI += "file://cnss.service"
SRC_URI += "file://device/qcom/wlan/${BASEMACHINE}/"
SRC_URI:append:sxrneo+= "file://sxrneo/dhcpcd.service"
SRC_URI:append:sxrneo+= "file://sxrneo/wlan_daemon.service"
SRC_URI:append:sxrneo+= "file://sxrneo/wpa_supplicant.service"
SRC_URI:append:sxrneo+= "file://sxrneo/wlan-conf_systemd_tmpfiles.conf"
SRC_URI:append:sxrneo+= "file://sxrneo/fi.w1.wpa_supplicant1.service"
SRC_URI:append:sxrneo+= "file://sxrneo/dbus-wpa_supplicant.conf"
SRC_URI:append:sxrneo+= "file://sxrneo/dbus-wpa_supplicant_testing.conf"
SRC_URI:append:kalama+= "file://sxrneo/wlan_daemon.service"
SRC_URI:append:qrb5165+= "file://sxrneo/wlan_daemon.service"
SRC_URI:append:kalama+= "file://sxrneo/wlan-conf_systemd_tmpfiles.conf"

# Update for each machine
S = "${WORKDIR}/mdm-init/"

do_install:append:mdm(){
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

do_install:append:sdxlemur(){
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

do_install:append:msm(){
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

do_install:append:neo(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		if grep -q "CONFIG_ICNSS2=m" ${STAGING_KERNEL_BUILDDIR}/.config
		then
			#systemd-tmpfiles service for wlan-conf
			install -d ${D}${sysconfdir}/tmpfiles.d
			install -m 0644 ${WORKDIR}/sxrneo/wlan-conf_systemd_tmpfiles.conf \
				-D ${D}${sysconfdir}/tmpfiles.d/wlan-conf_systemd_tmpfiles.conf
			install -d ${D}/etc/initscripts
			cp ${D}/etc/init.d/wlan ${D}/etc/initscripts/wlan
			install -d ${D}/etc/systemd/system/
			install -d ${D}/etc/systemd/system/multi-user.target.wants/
			install -m 0644 ${WORKDIR}/sxrneo/wlan_daemon.service -D ${D}/etc/systemd/system/wlan_daemon.service
			ln -sf /etc/systemd/system/wlan_daemon.service ${D}/etc/systemd/system/multi-user.target.wants/wlan_daemon.service
			install -m 0644 ${WORKDIR}/sxrneo/dhcpcd.service -D ${D}/etc/systemd/system/dhcpcd.service
			ln -sf /etc/systemd/system/dhcpcd.service ${D}/etc/systemd/system/multi-user.target.wants/dhcpcd.service
			install -m 0644 ${WORKDIR}/sxrneo/wpa_supplicant.service -D ${D}/etc/systemd/system/wpa_supplicant.service
			ln -sf /etc/systemd/system/wpa_supplicant.service ${D}/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
			install -m 0644 ${WORKDIR}/sxrneo/fi.w1.wpa_supplicant1.service -D ${D}/usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service
			install -m 0644 ${WORKDIR}/sxrneo/dbus-wpa_supplicant.conf -D ${D}/usr/share/dbus-1/system.d/dbus-wpa_supplicant.conf
			install -m 0644 ${WORKDIR}/sxrneo/dbus-wpa_supplicant_testing.conf -D ${D}/etc/dbus-1/system.d/dbus-wpa_supplicant_testing.conf

		fi

		rm ${D}/etc/init.d/wlan
	fi

	if [ -e "${WORKDIR}/device/qcom/wlan/${BASEMACHINE}/WCNSS_qcom_cfg_qca6750.ini" ];then
		install -m 0644 ${WORKDIR}/device/qcom/wlan/${BASEMACHINE}/WCNSS_qcom_cfg_qca6750.ini ${D}/lib/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini
	fi
}

do_install:append:kalama(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		#systemd-tmpfiles service for wlan-conf
		install -d ${D}${sysconfdir}/tmpfiles.d
		install -m 0644 ${WORKDIR}/sxrneo/wlan-conf_systemd_tmpfiles.conf \
				-D ${D}${sysconfdir}/tmpfiles.d/wlan-conf_systemd_tmpfiles.conf
		install -d ${D}/etc/initscripts
		cp ${D}/etc/init.d/wlan ${D}/etc/initscripts/wlan
		install -d ${D}/etc/systemd/system/
		install -m 0644 ${WORKDIR}/sxrneo/wlan_daemon.service -D ${D}/etc/systemd/system/wlan_daemon.service
		install -d ${D}/etc/systemd/system/multi-user.target.wants/
		ln -sf /etc/systemd/system/wlan_daemon.service \
			${D}/etc/systemd/system/multi-user.target.wants/wlan_daemon.service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
		install -d ${D}/etc/misc/wifi/
	fi
}

do_install:append:qrb5165(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		install -d ${D}/etc/initscripts
		cp ${D}/etc/init.d/wlan ${D}/etc/initscripts/wlan
		install -d ${D}/etc/systemd/system/
		install -m 0644 ${WORKDIR}/sxrneo/wlan_daemon.service -D ${D}/etc/systemd/system/wlan_daemon.service
		install -d ${D}/etc/systemd/system/multi-user.target.wants/
		ln -sf /etc/systemd/system/wlan_daemon.service \
			${D}/etc/systemd/system/multi-user.target.wants/wlan_daemon.service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
	fi
}
FILES:${PN} += "${userfsdatadir}/misc/wifi/*"
FILES:${PN} += "${base_libdir}/firmware/wlan/qca_cld/*"
FILES:${PN} += "/lib/firmware/wlan/qca_cld/* ${sysconfdir}/init.d/* "
FILES:${PN}:append:sxrneo += "/usr/share/dbus-1/system-services/*"
FILES:${PN}:append:sxrneo += "/usr/share/dbus-1/system.d/*"
FILES:${PN}:append:sxrneo += "/etc/dbus-1/system.d/*"

BASEPRODUCT = "${@d.getVar('PRODUCT', False)}"

EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'mdm9607', '--enable-target-mdm9607=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'mdm9650', '--enable-target-mdm9650=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'apq8096', '--enable-target-apq8096=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'apq8098', '--enable-target-apq8098=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'apq8009', '--enable-target-apq8009=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'apq8017', '--enable-target-apq8017=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'sdx20', '--enable-target-sdx20=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'sdxpoorwills', '--enable-target-sdxpoorwills=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'sdxprairie', '--enable-target-sdxprairie=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'sdxlemur', '--enable-target-sdxlemur=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'qcs40x', '--enable-target-qcs405-som1=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'qcs605', '--enable-target-qcs605=yes', '', d)}"

EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'apq8053', '--enable-pronto-wlan=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'apq8017', '--enable-pronto-wlan=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'neo', '--enable-target-sxrneo=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'kalama', '--enable-target-kalama=yes', '', d)}"
EXTRA_OECONF += "${@bb.utils.contains('BASEMACHINE', 'qrb5165', '--enable-target-qrb5165=yes', '', d)}"

# Enable qsap-wlan in place of pronto-wlan for Drones
EXTRA_OECONF:append:qsap += "--enable-snap-wlan=yes --enable-qsap-wlan=yes --enable-naples-wlan=yes"

# Enable drone-wlan in place of pronto-wlan for Drones
EXTRA_OECONF:append:drone += "'--enable-drone-wlan=yes"

# Enable robot-wlan according to variants
EXTRA_OECONF:append:robot-som += "--enable-robot-som-wlan=yes"
EXTRA_OECONF:remove:robot-rome += "--enable-robot-som-wlan=yes"
EXTRA_OECONF:append:robot-rome += "--enable-robot-wlan=yes"
EXTRA_OECONF:remove:robot-pronto += "--enable-robot-som-wlan=yes"
EXTRA_OECONF:append:robot-pronto += "--enable-pronto-wlan=yes"

INITSCRIPT_NAME   = "wlan_daemon"
INITSCRIPT_PARAMS = "remove"
INITSCRIPT_PARAMS:apq8009 = "${@bb.utils.contains('BASEPRODUCT', 'drone', 'start 01 2 3 4 5 . stop 2 0 1 6 .', 'start 98 5 . stop 2 0 1 6 .', d)}"
INITSCRIPT_PARAMS:apq8053 = "start 98 5 . stop 2 0 1 6 ."
INITSCRIPT_PARAMS:apq8017 = "start 98 5 . stop 2 0 1 6 ."
INITSCRIPT_PARAMS:apq8096 = "${@bb.utils.contains('BASEPRODUCT', 'drone', 'start 01 2 3 4 5 . stop 2 0 1 6 .', 'start 98 5 . stop 2 0 1 6 .', d)}"
