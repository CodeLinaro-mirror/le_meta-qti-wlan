include $(TOPDIR)/rules.mk
PKG_NAME:=cld80211-lib
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=BSD

LOCAL_SRC := $(TOPDIR)/src/hardware/qcom/wlan/cld80211-lib

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI-PACKAGES
  TITLE:=CLD80211-LIB
  DEPENDS:= +libcutils +libnl +liblog
endef

define Package/$(PKG_NAME)/Description
	cld80211-lib
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
	$(Build/Patch)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)
	mkdir -p  $(STAGING_DIR)/usr/lib
	mkdir -p  $(STAGING_DIR)/usr/share/pkgconfig
	mkdir -p  $(STAGING_DIR)/usr/include/cld80211-lib
	$(CP) $(PKG_BUILD_DIR)/cld80211-lib.pc $(STAGING_DIR)/usr/share/pkgconfig/
	$(CP) $(PKG_BUILD_DIR)/.libs/libcld80211.so* $(STAGING_DIR)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/*.h $(STAGING_DIR)/usr/include/cld80211-lib
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/.libs/libcld80211.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
