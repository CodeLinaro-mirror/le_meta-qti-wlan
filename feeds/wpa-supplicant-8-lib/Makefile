include $(TOPDIR)/rules.mk

PKG_NAME:=wpa-supplicant-8-lib
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=BSD-3-Clause

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

ifeq ($(BOARD),sdx75)
	TARGET_LOCAL_NAME :=sdxpinn
endif

TARGET_PATCH_EXIST := $(shell if [ -n "$(TARGET_LOCAL_NAME)" ]; then \
	echo "yes"; else echo "no"; fi)
ifeq ($(TARGET_PATCH_EXIST), yes)
	TARGET_PATCH_PATH := $(TARGET_LOCAL_NAME)
	COPY_PATCH_FILES := $(CP) ./files/$(TARGET_PATCH_PATH)/*.patch ./patches/
endif

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
	if [ -d "./patches/" ]; then \
		rm -rf ./patches; \
	fi
	mkdir patches
	${COPY_PATCH_FILES}
	$(Build/Patch)
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
