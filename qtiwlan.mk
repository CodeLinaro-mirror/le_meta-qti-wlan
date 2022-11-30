QTIWLAN:= wlan-conf wpa-supplicant-8-lib hostapd-daemon wlan-sigma-dut wpa-supplicant-qcacld

ifeq ($(BOARD),sdx75)
  QTIWLAN+=kmod-qcacld32-ll kmod-wlan-cnss
endif
