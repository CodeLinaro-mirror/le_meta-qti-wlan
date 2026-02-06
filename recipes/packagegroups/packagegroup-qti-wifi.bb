SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

MCC_EASYMESH_VERSION = "R1"

WLAN_IW_TOOL="${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', 'iw-wifi6e', 'iw', d)}"
QCACLD32_LL="${@oe.utils.conditional('BASEMACHINE', 'neo', 'qcacld32-ll-oot', 'qcacld32-ll', d)}"
QCACLD32_LL_KIWI="${@oe.utils.conditional('BASEMACHINE', 'neo', 'qcacld32-ll-kiwi', '', d)}"
EMESH_SP_MCC="${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', \
                    oe.utils.conditional('MCC_EASYMESH_VERSION', 'R6', \
                    'emesh-sp-mcc', '', d), '' ,d)}"
QCA_HYFI_BRIDGE_MCC="${@oe.utils.conditional('BASEMACHINE', 'sdxlemur', \
                    oe.utils.conditional('MCC_EASYMESH_VERSION', 'R6', \
                    'qca-hyfi-bridge-mcc', '', d), '' ,d)}"

RDEPENDS_packagegroup-qti-wifi_append_sxrneo = "tcpdump rfkill dnsmasq dhcpcd iperf2 iperf3"

RDEPENDS_packagegroup-qti-wifi = " \
        ${QCACLD32_LL} \
        ${WLAN_IW_TOOL} \
        ${QCACLD32_LL_KIWI} \
        wlan-conf \
        wlan-sigma-dut \
        hostap-daemon-qcacld \
        wpa-supplicant-8-lib \
        wpa-supplicant-qcacld \
        ${EMESH_SP_MCC} \
        ${QCA_HYFI_BRIDGE_MCC} \
        "
