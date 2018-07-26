# WLAN open source Packages
IMAGE_INSTALL += "${@bb.utils.contains('TARGET_ARCH', 'aarch64','qcacld32-ll','',d)}"
IMAGE_INSTALL += "hostap-daemon-qcacld"
IMAGE_INSTALL += "wpa-supplicant-qcacld"
