# WLAN open source Packages
IMAGE_INSTALL += "qcacld-utils"
IMAGE_INSTALL += "hostap-daemon-qcacld"
IMAGE_INSTALL += "wpa-supplicant-qcacld"

IMAGE_INSTALL:append:qsap += "qcacld-hl"
IMAGE_INSTALL:append:qsap += "wlan-services"

IMAGE_INSTALL:append:drone += "qcacld-hl"
IMAGE_INSTALL:append:drone += "wlan-services"

IMAGE_INSTALL:append:robot-som += "qcacld-hl"
IMAGE_INSTALL:append:robot-som += "wlan-services"

IMAGE_INSTALL:remove:robot-rome += "qcacld-hl"
IMAGE_INSTALL:append:robot-rome += "qcacld-hl-rome"

# robot-som is base distro of robot, need to remove what base had first
IMAGE_INSTALL:remove:robot-pronto += "qcacld-hl"
IMAGE_INSTALL:remove:robot-pronto += "wlan-services"
IMAGE_INSTALL:append:robot-pronto += "wcnss"
IMAGE_INSTALL:append:robot-pronto += "wlan-opensource"
