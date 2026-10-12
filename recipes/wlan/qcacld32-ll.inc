WLAN_BB = 'autotools-brokensep module'
WLAN_BB:remove:sa535m = 'qperf'
inherit ${WLAN_BB} deploy

LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/${LICENSE};md5=f3b90e78ea0cffb20bf5cca7947a896d"

_LINUX_BUILD_TOP = "${UNPACKDIR}/wlan"
EXTRA_OEMAKE:append = " LINUX_BUILD_TOP=${_LINUX_BUILD_TOP}"

# Deploy unstripped kernel modules into ${DEPLOYDIR}/kernel_modules/${PN} for debugging purposes
do_deploy() {
    install -d ${DEPLOYDIR}/kernel_modules/${PN}
    cd ${S}
    for mod in *.ko; do
        if [ -f $mod ]; then
            install -m 0644 $mod ${DEPLOYDIR}/kernel_modules/${PN}
        fi
    done
}
addtask deploy after do_install before do_module_signing