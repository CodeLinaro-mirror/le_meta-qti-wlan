include $(TOPDIR)/rules.mk

PKG_NAME:=wlan-sigma-dut
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=BSD-3-Clause

LOCAL_SRC := $(TOPDIR)/src/wlan/utils/sigma-dut

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -DOPENWRT_BUILD -DLINUX_EMBEDDED
TARGET_CPPFLAGS += -I$(STAGING_DIR)/usr/include/libnl3

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI-PACKAGES
  TITLE:=SIGMA DUT
  DEPENDS := +libnl +libnl-genl
endef

define Package/$(PKG_NAME)/Description
	sigma dut tool
endef

ifeq ($(BOARD),sdx75)
	COPY_PATCH_FILES := $(CP) ./patches/sdxpinn/*.patch ./patches/
endif

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
	${COPY_PATCH_FILES}
	$(Build/Patch)
endef

define Build/InstallDev
	@true
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/sigma_dut $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
