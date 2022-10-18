include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wlan-cnss
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

LOCAL_SRC ?= $(TOPDIR)/src/wlan/platform/

include $(INCLUDE_DIR)/package.mk

CNSS_MAKEOPTS = CONFIG_CNSS_OUT_OF_TREE=y \
		CONFIG_MHI_BUS_MISC=y \
		M="$(PKG_BUILD_DIR)" \
		ARCH=$(LINUX_KARCH) \
		TARGET=arm64 \
		CC=$(KERNEL_CC) \
		TOOLPREFIX="$(KERNEL_CROSS)" \
		TOOLPATH="$(KERNEL_CROSS)" \
		CROSS_COMPILE=$(TARGET_CROSS) 

define KernelPackage/$(PKG_NAME)
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=CNSS platform driver
endef

define KernelPackage/$(PKG_NAME)/Description
	CNSS2 platform driver
endef

define Build/Prepare
	export WLAN_PLATFORM_ROOT=$(TOPDIR)/src/wlan/platform/
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
			$(CNSS_MAKEOPTS)  
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)
	mkdir -p  $(1)/lib/modules/$(LINUX_VERSION)-debug/extra/
	$(CP) $(PKG_BUILD_DIR)/cnss2/cnss2.ko $(1)/lib/modules/$(LINUX_VERSION)-debug/extra/
endef

define KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/lib/modules/$(LINUX_VERSION)-debug/extra/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss2/cnss2.ko $(1)/lib/modules/$(LINUX_VERSION)-debug/extra/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
