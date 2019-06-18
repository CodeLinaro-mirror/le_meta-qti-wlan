# WLAN open source Packages
IMAGE_INSTALL += "qcacld32-ll"
IMAGE_INSTALL += "hostap-daemon-qcacld"
IMAGE_INSTALL += "wpa-supplicant-qcacld"
IMAGE_INSTALL += "wpa-supplicant-8-lib"
IMAGE_INSTALL += "cld80211-lib"
IMAGE_INSTALL += "wlan-conf"
IMAGE_INSTALL += "${@bb.utils.contains('DISTRO_FEATURES', 'no-test-bundle','qcacld32-ll-nf-debug','',d)}"
