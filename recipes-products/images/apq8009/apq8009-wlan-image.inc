# WLAN open source Packages
IMAGE_INSTALL += "wcnss"
IMAGE_INSTALL += "wlan-opensource"
IMAGE_INSTALL += "qcacld-utils"
IMAGE_INSTALL += "hostap-daemon-qcacld"
IMAGE_INSTALL += "wpa-supplicant-qcacld"

IMAGE_INSTALL += "${@base_conditional('PRODUCT','drone', 'qcacld-hl', '', d)}"
IMAGE_INSTALL:remove = "${@base_conditional('PRODUCT','drone', 'wlan-opensource', '', d)}"
IMAGE_INSTALL += "${@base_conditional('PRODUCT','drone', 'wlan-services', '', d)}"

IMAGE_INSTALL += "${@base_conditional('PRODUCT','qsap', 'qcacld-hl', '', d)}"
IMAGE_INSTALL:remove = "${@base_conditional('PRODUCT','qsap', 'wlan-opensource', '', d)}"
IMAGE_INSTALL += "${@base_conditional('PRODUCT','qsap', 'wlan-services', '', d)}"
IMAGE_INSTALL:remove = "${@base_conditional('PRODUCT','qsap', 'wcnss', '', d)}"

IMAGE_INSTALL += "${@base_conditional('DISTRO','robot-som', 'qcacld-hl', '', d)}"
IMAGE_INSTALL:remove = "${@base_conditional('DISTRO','robot-som', 'wlan-opensource', '', d)}"
IMAGE_INSTALL += "${@base_conditional('DISTRO','robot-som', 'wlan-services', '', d)}"
IMAGE_INSTALL:remove = "${@base_conditional('DISTRO','robot-som', 'wcnss', '', d)}"
IMAGE_INSTALL += "${@base_conditional('DISTRO','robot-som-ros', 'qcacld-hl', '', d)}"
IMAGE_INSTALL:remove = "${@base_conditional('DISTRO','robot-som-ros', 'wlan-opensource', '', d)}"
IMAGE_INSTALL += "${@base_conditional('DISTRO','robot-som-ros', 'wlan-services', '', d)}"
IMAGE_INSTALL:remove = "${@base_conditional('DISTRO','robot-som-ros', 'wcnss', '', d)}"
