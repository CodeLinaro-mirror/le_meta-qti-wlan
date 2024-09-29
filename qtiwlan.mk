QTIWLAN:= wlan-conf wpa-supplicant-8-lib hostapd-daemon wlan-sigma-dut

ifeq ($(BOARD),sdx85)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss2 cld80211-lib
endif

ifeq ($(BOARD),sdx75)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss2 cld80211-lib freeradius3 freeradius3-default freeradius3-utils wpa-supplicant-qcacld
  QTIWLAN+=kmod-emesh-sp-mcc
endif

ifeq ($(BOARD),sdx35)
  QTIWLAN+=kmod-qcacld32-ll kmod-qcacld-ll kmod-wlan-cnss2 kmod-wlan-cnss-legacy cld80211-lib wpa-supplicant-qcacld
endif
