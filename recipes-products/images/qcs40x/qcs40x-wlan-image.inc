# WLAN open source Packages
IMAGE_INSTALL += "qcacld32-ll"
IMAGE_INSTALL += "hostap-daemon-qcacld"
IMAGE_INSTALL += "wpa-supplicant-qcacld"
IMAGE_INSTALL_append_qcs403-som2 += "qcacld32-ll-nf-debug"
IMAGE_INSTALL += "wpa-supplicant-8-lib"
