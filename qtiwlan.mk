include $(INCLUDE_DIR)/target.mk

ifeq ($(PROFILE),mbb-min)
  QTIWLAN:=
else
  QTIWLAN:= wlan-conf wpa-supplicant-8-lib hostapd-daemon wlan-sigma-dut  wpa-supplicant-qcacld wlan-uci
endif

ifeq ($(BOARD),echo)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss2 cld80211-lib kmod-wlan-dts-oss
endif

ifeq ($(BOARD),sdx85)
  QTIWLAN+=kmod-emesh-sp-mcc
ifneq ($(PROFILE),mbb-min)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss2 cld80211-lib
endif
endif

ifeq ($(BOARD),sdx75)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss2 cld80211-lib freeradius3 freeradius3-default freeradius3-utils
  QTIWLAN+=kmod-emesh-sp-mcc
endif

ifeq ($(BOARD),sdx35)
  QTIWLAN+=kmod-qcacld32-ll kmod-qcacld-ll kmod-wlan-cnss2 kmod-wlan-cnss-legacy cld80211-lib
endif
