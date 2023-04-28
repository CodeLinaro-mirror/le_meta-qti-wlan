QTIWLAN:= wlan-conf wpa-supplicant-8-lib hostapd-daemon wlan-sigma-dut wpa-supplicant-qcacld

ifeq ($(BOARD),sdx75)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss2 cld80211-lib
endif

ifeq ($(BOARD),sdx35)
  QTIWLAN+=kmod-qcacld32-ll kmod-qcacld-ll kmod-wlan-cnss2 kmod-wlan-cnss-legacy cld80211-lib
endif
