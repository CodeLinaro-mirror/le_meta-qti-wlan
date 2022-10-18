include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qcacld32-ll
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

ifeq ($(VARIANT),release)
  COMPILE_MODE := release
else
  COMPILE_MODE := debug
endif

LOCAL_SRC := $(TOPDIR)/src/wlan
EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra

include $(INCLUDE_DIR)/package.mk

TARGET_MAKEOPTS := CONFIG_ARCH_SDXPINN=y \
		    CONFIG_CNSS_KIWI_V2=y

define KernelPackage/$(PKG_NAME)
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=WLAN HOST DRIVER
  DEPENDS := +${TARGET_DEPENDS}
endef

QCACLD32_LL_MAKEOPTS=  M="$(PKG_BUILD_DIR)/qcacld-3.0" \
			CONFIG_QCA_CLD_WLAN_PROFILE=default \
			${TARGET_MAKEOPTS} \
			CONFIG_HIF_PCI=y \
			KERNEL_PATH=${LINUX_DIR} \
			KERNEL_SRC=${LINUX_DIR} \
			KERNEL_VERSION=${LINUX_VERSION} \
			ARCH=$(LINUX_KARCH) \
			TARGET=arm64 \
			CC=$(KERNEL_CC) \
			TOOLPREFIX="$(KERNEL_CROSS)" \
			TOOLPATH="$(KERNEL_CROSS)" \
			CROSS_COMPILE=$(TARGET_CROSS) \
			CONFIG_CNSS_SDIO=n \
			CONFIG_CLD_HL_SDIO_CORE=n

define  KernelPackage/$(PKG_NAME)/Description
	wlan host driver
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/qcacld-3.0 $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/qca-wifi-host-cmn $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/fw-api $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -j32 -C "$(LINUX_DIR)" $(QCACLD32_LL_MAKEOPTS)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)
	mkdir -p $(1)/$(EXTRA_ADDR)
	mkdir -p $(1)/usr/include/qcacld
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/wlan.ko $(PKG_BUILD_DIR)/qcacld-3.0/wlan.ko.unstripped
	$(TOOLCHAIN_DIR)/aarch64-openwrt-linux-musl/bin/strip --strip-unneed $(PKG_BUILD_DIR)/qcacld-3.0/wlan.ko
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/wlan.ko $(1)/$(EXTRA_ADDR)/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/utils/nlink/inc/wlan_nlink_common.h $(1)/usr/include/qcacld/
endef

define  KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/ $(1)/usr/include/qcacld/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/wlan.ko $(1)/$(EXTRA_ADDR)/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/utils/nlink/inc/wlan_nlink_common.h $(1)/usr/include/qcacld/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
