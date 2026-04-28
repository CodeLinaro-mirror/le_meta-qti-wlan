include $(TOPDIR)/rules.mk

PKG_NAME:=wlan-uci
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=BSD-3-Clause-Clear

LOCAL_SRC := files

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -DOPENWRT_BUILD

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI-PACKAGES
  TITLE:=WLAN SCRIPT FILES
endef

define Package/$(PKG_NAME)/Description
	wlan script files
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	echo "****** Do nothing ******"
endef

define Build/InstallDev
	@true
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(STAGING_DIR)
	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/misc/wifi
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/data/vendor/wifi/default_config
	$(CP) files/qcacld32.sh $(1)/lib/wifi/
	$(CP) files/qcacld32-modules $(1)/lib/wifi/
	$(CP) files/qcacld32-utils.sh $(1)/lib/wifi/
	$(CP) files/wpa_supplicant.sh $(1)/lib/wifi/
	$(CP) files/hostapd.sh $(1)/lib/wifi/
	$(CP) files/wireless $(1)/etc/config/
	$(CP) files/wireless $(1)/data/vendor/wifi/default_config/
	$(CP) files/2g_wireless $(1)/etc/misc/wifi/
	$(CP) files/5g_wireless $(1)/etc/misc/wifi/
	$(CP) files/6g_wireless $(1)/etc/misc/wifi/
	$(CP) files/sdxlemur/qcacfg80211.config $(1)/etc/config/qcacfg80211
	$(INSTALL_BIN) files/ucitool $(1)/usr/sbin/
ifeq ($(BOARD),sdx35)
	mv $(1)/lib/wifi/qcacld32-modules $(1)/etc/misc/wifi/qcacld32-modules.hsp
	$(CP) files/qcacld32-modules.rome $(1)/etc/misc/wifi/
	$(CP) files/qcacld32-modules.rome.sdio $(1)/etc/misc/wifi/
	$(LN) -rsf $(1)/etc/misc/wifi/qcacld32-modules $(1)/lib/wifi/qcacld32-modules
	$(LN) -rsf $(1)/etc/misc/wifi/qcacld32-modules.hsp $(1)/etc/misc/wifi/qcacld32-modules
endif
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
