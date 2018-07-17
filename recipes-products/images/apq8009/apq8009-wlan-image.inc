# WLAN open source Packages
IMAGE_INSTALL += "qcacld-utils"
IMAGE_INSTALL += "hostap-daemon-qcacld"
IMAGE_INSTALL += "wpa-supplicant-qcacld"

IMAGE_INSTALL_append_qsap += "qcacld-hl"
IMAGE_INSTALL_append_qsap += "wlan-services"

IMAGE_INSTALL_append_drone += "qcacld-hl"
IMAGE_INSTALL_append_drone += "wlan-services"

IMAGE_INSTALL_append_robot-som += "qcacld-hl"
IMAGE_INSTALL_append_robot-som += "wlan-services"

# robot-som is base distro of robot, need to remove what base had first
#IMAGE_INSTALL_remove_robot += "qcacld-hl"
#IMAGE_INSTALL_remove_robot += "wlan-services"
#IMAGE_INSTALL_append_robot += "wcnss"
#IMAGE_INSTALL_append_robot += "wlan-opensource"
