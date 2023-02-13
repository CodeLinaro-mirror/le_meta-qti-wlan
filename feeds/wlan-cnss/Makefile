include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wlan-cnss
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

ifeq ($(TARGET_VARIANT),perf)
  COMPILE_MODE :=perf
else
  COMPILE_MODE :=debug
endif

LOCAL_SRC ?= $(TOPDIR)/src/wlan/platform/
EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra

include $(INCLUDE_DIR)/package.mk

CNSS_MAKEOPTS = CONFIG_CNSS_OUT_OF_TREE=y \
		CONFIG_MHI_BUS_MISC=y \
		M="$(PKG_BUILD_DIR)"

ifeq ($(BOARD),sdx35)
	CNSS_MAKEOPTS += CONFIG_CNSS=m \
			 CONFIG_CNSS_PCI=y \
			 CONFIG_CNSS_ASYNC=y \
			 CONFIG_CNSS_LOGGER=m \
			 CONFIG_CNSS_CRYPTO=m
endif

define KernelPackage/$(PKG_NAME)
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=CNSS platform driver
endef

define KernelPackage/$(PKG_NAME)/Description
	CNSS2 platform driver
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" $(CNSS_MAKEOPTS) \
	modules
endef

define Build/InstallDev
	@true
endef

define KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss2/cnss2.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss/cnss.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss/logger/logger.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_crypto/cnss_crypto.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/cnss_utils.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/cnss_plat_ipc_qmi_svc.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/wlan_firmware_service.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_genl/cnss_nl.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_prealloc/cnss_prealloc.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss2/cnss2.ko $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss/cnss.ko $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
