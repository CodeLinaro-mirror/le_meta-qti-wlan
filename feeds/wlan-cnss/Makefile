include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wlan-cnss
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

ifeq ($(VARIANT),perf)
  COMPILE_MODE :=perf
else
  COMPILE_MODE :=debug
endif

LOCAL_SRC ?= $(TOPDIR)/src/wlan/platform/
EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra

include $(INCLUDE_DIR)/package.mk

CNSS_MAKEOPTS = CONFIG_CNSS_OUT_OF_TREE=y \
		CONFIG_MHI_BUS_MISC=y \
		M="$(PKG_BUILD_DIR)" \
		TARGET=$(LINUX_KARCH) \
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
	$(MAKE) -C "$(LINUX_DIR)" $(CNSS_MAKEOPTS)
endef

define Build/InstallDev
	@true
endef

define KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss2/cnss2.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/cnss_utils.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/cnss_plat_ipc_qmi_svc.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/wlan_firmware_service.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_genl/cnss_nl.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_prealloc/cnss_prealloc.ko $(1)/$(EXTRA_ADDR)/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
