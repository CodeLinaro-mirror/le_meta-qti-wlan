QTIWLAN:= wlan-conf wpa-supplicant-8-lib hostapd-daemon wlan-sigma-dut wpa-supplicant-qcacld

ifeq ($(BOARD),sdx75)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss2 cld80211-lib freeradius3 freeradius3-default freeradius3-utils
endif

ifeq ($(BOARD),sdx35)
  QTIWLAN+=kmod-qcacld32-ll kmod-qcacld-ll kmod-qcacld-ll-sdio kmod-wlan-cnss2 kmod-wlan-cnss-legacy kmod-wlan-cnss-sdio cld80211-lib
endif
