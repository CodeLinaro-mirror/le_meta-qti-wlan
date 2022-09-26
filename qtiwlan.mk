QTIWLAN:= qcacld32-ll wlan-conf wpa-supplicant-8-lib hostapd-daemon wlan-cnss wlan-sigma-dut wpa-supplicant-qcacld

## Eg: Add target specific packages.
##ifeq ($(TARGET_MACHINE),sdx75)
##  QTIWLAN+=newloc-package
##endif
