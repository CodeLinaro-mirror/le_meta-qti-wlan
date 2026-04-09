inherit module deploy

SUMMARY = "Wlan devicetree"
DESCRIPTION = "Build QTI wlan devicetree to dtbo"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/\
BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"

DEPENDS += "virtual/kernel"

WLAN_SRC_PATH = "${@'wlan' if os.path.exists(os.path.join(d.getVar('WORKSPACE'), 'wlan/wlan-devicetree')) else 'wlan-proprietary'}"

SRC_URI = "file://${WLAN_SRC_PATH}/wlan-devicetree/"
S = "${WORKDIR}/${WLAN_SRC_PATH}/wlan-devicetree"

FILESPATH =+ "${WORKSPACE}:"
do_configure[depends] = "virtual/kernel:do_deploy"

EXTRA_OEMAKE += "TARGET_SUPPORT=${BASEMACHINE}"
EXTRA_OEMAKE += "M=${S}"

MAKE_TARGETS = "dtbs"

KERNEL_CC = "${STAGING_BINDIR_NATIVE}/clang/bin/clang -target ${TARGET_ARCH}${TARGET_VENDOR}-${TARGET_OS}"

do_install() {
    :
}

do_deploy() {
    install -d ${DEPLOYDIR}/tech_dtbs
    install -m 0644 ${S}/*.dtbo ${DEPLOYDIR}/tech_dtbs/
}

addtask do_deploy after do_install

ALLOW_EMPTY:${PN} = "1"
