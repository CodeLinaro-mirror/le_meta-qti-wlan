inherit autotools systemd update-rc.d qperf useradd
DESCRIPTION = "Device specific config"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"
PV = "1.0"
PR = "r3"
DEPENDS += "virtual/kernel"

FILESPATH =+ "${WORKSPACE}:"
MACHINE_CONFIG = "${BASEMACHINE}"
MACHINE_CONFIG:kera = "sun"

# Provide a baseline
SRC_URI = "file://mdm-init/ \
           file://wlan_daemon.service \
           file://cnss.service \
           file://device/qcom/wlan/${MACHINE_CONFIG} \
           file://neo"

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

do_install:msm() {
       APQ8009_NON_QSAP="${@bb.utils.contains('BASEMACHINE', 'apq8009', \
                       bb.utils.contains('BASEPRODUCT', 'qsap', 'false', 'true', d), 'true', d)}"

       if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
               install -d ${D}/etc/initscripts
               cp ${D}/etc/init.d/wlan ${D}/etc/initscripts/wlan
               install -d ${D}/etc/systemd/system/
               install -d ${D}/etc/systemd/system/multi-user.target.wants/
               if [ "$APQ8009_NON_QSAP" = "true" ]; then
                       install -m 0644 ${WORKDIR}/wlan_daemon.service -D ${D}/etc/systemd/system/wlan_daemon.service
                       ln -sf /etc/systemd/system/wlan_daemon.service \
                               ${D}/etc/systemd/system/multi-user.target.wants/wlan_daemon.service
               fi
       else
               if [ "$APQ8009_NON_QSAP" = "true" ]; then
                       install -m 0755 ${S}/wlan_daemon -D ${D}${sysconfdir}/init.d/wlan_daemon
               fi
       fi
}

do_install_common_service(){
	# Install common systemd dirs
	install -d ${D}${sysconfdir}/tmpfiles.d
	install -d ${D}/etc/initscripts
	install -d ${D}/etc/systemd/system/
	install -d ${D}/etc/systemd/system/multi-user.target.wants/
	# Install common systemd files
	install -m 0644 ${WORKDIR}/neo/wlan-conf_systemd_tmpfiles.conf \
		-D ${D}${sysconfdir}/tmpfiles.d/wlan-conf_systemd_tmpfiles.conf
	cp ${D}/etc/init.d/wlan ${D}/etc/initscripts/wlan
	install -m 0644 ${WORKDIR}/neo/wlan_daemon.service -D ${D}/etc/systemd/system/wlan_daemon.service
	ln -sf /etc/systemd/system/wlan_daemon.service ${D}/etc/systemd/system/multi-user.target.wants/wlan_daemon.service
}

do_install:append:neo(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		if grep -q "CONFIG_ICNSS2=m" ${STAGING_KERNEL_BUILDDIR}/.config
		then
			do_install_common_service
			install -m 0644 ${WORKDIR}/neo/dhcpcd.service -D ${D}/etc/systemd/system/dhcpcd.service
			ln -sf /etc/systemd/system/dhcpcd.service ${D}/etc/systemd/system/multi-user.target.wants/dhcpcd.service
			install -m 0644 ${WORKDIR}/neo/wpa_supplicant.service -D ${D}/etc/systemd/system/wpa_supplicant.service
			ln -sf /etc/systemd/system/wpa_supplicant.service ${D}/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
			install -m 0644 ${WORKDIR}/neo/fi.w1.wpa_supplicant1.service -D ${D}/usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service
			install -m 0644 ${WORKDIR}/neo/dbus-wpa_supplicant.conf -D ${D}/usr/share/dbus-1/system.d/dbus-wpa_supplicant.conf
			install -m 0644 ${WORKDIR}/neo/dbus-wpa_supplicant_testing.conf -D ${D}/etc/dbus-1/system.d/dbus-wpa_supplicant_testing.conf

		fi
	fi

	if [ -e "${WORKDIR}/device/qcom/wlan/${BASEMACHINE}/WCNSS_qcom_cfg_qca6750.ini" ];then
		install -m 0644 ${WORKDIR}/device/qcom/wlan/${BASEMACHINE}/WCNSS_qcom_cfg_qca6750.ini ${D}/lib/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini
	fi
}

do_install:append:kalama(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		do_install_common_service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
		install -d ${D}/etc/misc
		ln -sf ${userfsdatadir}/misc/wifi ${D}/etc/misc/wifi
	fi
}

do_install:append:qrb5165(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		do_install_common_service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
	fi
}

do_install:append:qcs40x(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		do_install_common_service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
		install -d ${D}/etc/misc/wifi/
	fi
}

do_install:append:pineapple(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		do_install_common_service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
		install -d ${D}/etc/misc
		ln -sf ${userfsdatadir}/misc/wifi ${D}/etc/misc/wifi
	fi
}

do_install:append:qcm2290-mtp(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		do_install_common_service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
		install -d ${D}/etc/misc/wifi/
	fi
}

do_install:append:ar-sg1(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		do_install_common_service
		ln -sf /etc/systemd/system/dhcpcd.service ${D}/etc/systemd/system/multi-user.target.wants/dhcpcd.service
		install -m 0644 ${WORKDIR}/neo/wpa_supplicant.service -D ${D}/etc/systemd/system/wpa_supplicant.service
		ln -sf /etc/systemd/system/wpa_supplicant.service ${D}/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
		install -m 0644 ${WORKDIR}/neo/fi.w1.wpa_supplicant1.service -D ${D}/usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service
		install -m 0644 ${WORKDIR}/neo/dbus-wpa_supplicant.conf -D ${D}/usr/share/dbus-1/system.d/dbus-wpa_supplicant.conf
		install -m 0644 ${WORKDIR}/neo/dbus-wpa_supplicant_testing.conf -D ${D}/etc/dbus-1/system.d/dbus-wpa_supplicant_testing.conf
	fi
}

do_install:append:kera(){
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		do_install_common_service
		install -d ${D}/etc/systemd/network/
		ln -sf /dev/null ${D}/etc/systemd/network/99-default.link
		install -d ${D}/etc/misc/wifi/
	fi
}

FILES:${PN} += "${userfsdatadir}/misc/wifi/*"
FILES:${PN} += "${base_libdir}/firmware/wlan/qca_cld/*"
FILES:${PN} += "${sysconfdir}/init.d/* "
FILES:${PN}:append:neo = " /usr/share/dbus-1/system-services/*"
FILES:${PN}:append:neo = " /usr/share/dbus-1/system.d/*"
FILES:${PN}:append:neo = " /etc/dbus-1/system.d/*"

BASEPRODUCT = "${@d.getVar('PRODUCT', False)}"

ENABLE_TARGET_FLAG = "--enable-target-${BASEMACHINE}=yes"
ENABLE_TARGET_FLAG:qcs40x = "--enable-target-qcs405-som1=yes"
ENABLE_TARGET_FLAG:apq8053 = "--enable-pronto-wlan=yes"
ENABLE_TARGET_FLAG:apq8017 = "--enable-pronto-wlan=yes"

EXTRA_OECONF += "${ENABLE_TARGET_FLAG}"


# Enable qsap-wlan in place of pronto-wlan for Drones
EXTRA_OECONF:append:qsap = " --enable-snap-wlan=yes --enable-qsap-wlan=yes --enable-naples-wlan=yes"

# Enable drone-wlan in place of pronto-wlan for Drones
EXTRA_OECONF:append:drone = " --enable-drone-wlan=yes"

# Enable robot-wlan according to variants
EXTRA_OECONF:append:robot-som = " --enable-robot-som-wlan=yes"
EXTRA_OECONF:remove:robot-rome = "--enable-robot-som-wlan=yes"
EXTRA_OECONF:append:robot-rome = " --enable-robot-wlan=yes"
EXTRA_OECONF:remove:robot-pronto = "--enable-robot-som-wlan=yes"
EXTRA_OECONF:append:robot-pronto = " --enable-pronto-wlan=yes"

INITSCRIPT_NAME   = "wlan_daemon"
INITSCRIPT_PARAMS = "remove"
INITSCRIPT_PARAMS:apq8009 = "${@bb.utils.contains('BASEPRODUCT', 'drone', 'start 01 2 3 4 5 . stop 2 0 1 6 .', 'start 98 5 . stop 2 0 1 6 .', d)}"
INITSCRIPT_PARAMS:apq8053 = "start 98 5 . stop 2 0 1 6 ."
INITSCRIPT_PARAMS:apq8017 = "start 98 5 . stop 2 0 1 6 ."
INITSCRIPT_PARAMS:apq8096 = "${@bb.utils.contains('BASEPRODUCT', 'drone', 'start 01 2 3 4 5 . stop 2 0 1 6 .', 'start 98 5 . stop 2 0 1 6 .', d)}"
