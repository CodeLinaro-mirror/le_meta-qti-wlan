include $(TOPDIR)/rules.mk

PKG_NAME:=wpa-supplicant-8-lib
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

LOCAL_SRC := $(TOPDIR)/src/hardware/qcom/wlan/qcwcn/wpa_supplicant_8_lib

WPA_SUPPLICANT_DIR := $(TOPDIR)/src/external/wpa_supplicant_8


include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -DOPENWRT_BUILD

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI-PACKAGES
  TITLE:=HOSTAPD
  DEPENDS:= +libcutils +libnl +liblog
endef

define Package/$(PKG_NAME)/Description
	wpa_supplicant library
endef

CONFIGURE_ARGS += WPA_SUPPLICANT_DIR=$(WPA_SUPPLICANT_DIR)

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)
	mkdir -p  $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/.libs/libwpa_supplicant_8_lib.so* $(1)/usr/lib/
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/.libs/libwpa_supplicant_8_lib.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
