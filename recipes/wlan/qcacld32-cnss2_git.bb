DESCRIPTION = "Qualcomm Atheros CNSS2"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=550794465ba0ec5312d6919e203a55f9"

PR = "r0"

inherit systemd

FILESPATH =+ "${WORKSPACE}:"

SRC_URI = "file://init_qti_cnss2_auto.service \
           file://init.qti.cnss2_on.sh \
           file://init.qti.cnss2_off.sh \
          "

# Update for each machine
S = "${WORKDIR}"

FILES_${PN} += "/lib/systemd/system"

do_install_append_auto() {
	install -d ${D}${bindir}
	install -D -m 0755 ${WORKDIR}/init.qti.cnss2_on.sh ${D}${bindir}/init.qti.cnss2_on.sh
	install -D -m 0755 ${WORKDIR}/init.qti.cnss2_off.sh ${D}${bindir}/init.qti.cnss2_off.sh
	install -d ${D}${systemd_unitdir}/system
	install -d ${D}${systemd_unitdir}/system/multi-user.target.wants
	install -m 0644 ${WORKDIR}/init_qti_cnss2_auto.service ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service
	ln -rsf ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service \
	          ${D}${systemd_unitdir}/system/multi-user.target.wants/init_qti_cnss2_auto.service
}

do_install_append_sa515m() {
	install -d ${D}${bindir}
	install -D -m 0755 ${WORKDIR}/init.qti.cnss2_on.sh ${D}${bindir}/init.qti.cnss2_on.sh
	install -D -m 0755 ${WORKDIR}/init.qti.cnss2_off.sh ${D}${bindir}/init.qti.cnss2_off.sh
	install -d ${D}${systemd_unitdir}/system
	install -d ${D}${systemd_unitdir}/system/multi-user.target.wants
	install -m 0644 ${WORKDIR}/init_qti_cnss2_auto.service ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service
	ln -rsf ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service \
	          ${D}${systemd_unitdir}/system/multi-user.target.wants/init_qti_cnss2_auto.service
}


do_install_append_sa525m() {
        install -d ${D}${bindir}
        install -D -m 0755 ${WORKDIR}/init.qti.cnss2_on.sh ${D}${bindir}/init.qti.cnss2_on.sh
        install -D -m 0755 ${WORKDIR}/init.qti.cnss2_off.sh ${D}${bindir}/init.qti.cnss2_off.sh
        install -d ${D}${systemd_unitdir}/system
        install -d ${D}${systemd_unitdir}/system/multi-user.target.wants
        install -m 0644 ${WORKDIR}/init_qti_cnss2_auto.service ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service
        ln -rsf ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service \
                  ${D}${systemd_unitdir}/system/multi-user.target.wants/init_qti_cnss2_auto.service
}

do_install_append_sa410m() {
        install -d ${D}${bindir}
        install -D -m 0755 ${WORKDIR}/init.qti.cnss2_on.sh ${D}${bindir}/init.qti.cnss2_on.sh
        install -D -m 0755 ${WORKDIR}/init.qti.cnss2_off.sh ${D}${bindir}/init.qti.cnss2_off.sh
        install -d ${D}${systemd_unitdir}/system
        install -d ${D}${systemd_unitdir}/system/multi-user.target.wants
        install -m 0644 ${WORKDIR}/init_qti_cnss2_auto.service ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service
        ln -rsf ${D}${systemd_unitdir}/system/init_qti_cnss2_auto.service \
                  ${D}${systemd_unitdir}/system/multi-user.target.wants/init_qti_cnss2_auto.service
}
