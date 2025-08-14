include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wlan-dts-oss
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=ISC

LOCAL_SRC := $(TOPDIR)/src/vendor/qcom/opensource/wlan/wlan-devicetree

include $(INCLUDE_DIR)/package.mk

define KernelPackage/$(PKG_NAME)
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=WLAN DTS FILES
endef

define KernelPackage/$(PKG_NAME)/Description
	wlan dts files
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endef

MAKE_OPTS:= \
	M="$(PKG_BUILD_DIR)"

ifeq ($(BOARD),sdxecho)
MAKE_OPTS += CONFIG_ARCH_SDXECHO=y
endif

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
			$(MAKE_OPTS) \
			modules
endef

define Build/InstallDev
	@true
endef

define KernelPackage/$(PKG_NAME)/install
	mkdir -p $(LINUX_DIR)/../techpack-dtbos
	$(CP) $(PKG_BUILD_DIR)/*.dtbo $(LINUX_DIR)/../techpack-dtbos/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
