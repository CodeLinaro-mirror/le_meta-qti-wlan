include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qcacld32-ll
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

ifeq ($(TARGET_VARIANT),perf)
  COMPILE_MODE :=perf
else
  COMPILE_MODE :=debug
endif

LOCAL_SRC := $(TOPDIR)/src/wlan
EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra

include $(INCLUDE_DIR)/package.mk

ifeq ($(BOARD),sdx75)

TARGET_MAKEOPTS := CONFIG_ARCH_SDXPINN=y \
		   CONFIG_CNSS_KIWI_V2=y \
		   CONFIG_QCA_CLD_WLAN_PROFILE=kiwi_v2 \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS2=m \
		   CONFIG_CNSS2_QMI=y \
		   CONFIG_CNSS_QMI_SVC=m \
		   CONFIG_CNSS_PLAT_IPC_QMI_SVC=m \
		   CONFIG_CNSS_GENL=m \
		   CONFIG_CNSS_UTILS=m \
		   CONFIG_WCNSS_MEM_PRE_ALLOC=m \
		   KERNEL_SUPPORTS_NESTED_COMPOSITES=n

WLAN_PLATFORM_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss-${PKG_VERSION}/Module.symvers
TARGET_MAKEOPTS += KBUILD_EXTRA_SYMBOLS=$(WLAN_PLATFORM_SYMBOLS)
else ifeq ($(BOARD),sdx35)
TARGET_MAKEOPTS := CONFIG_WLAN_MEMORY_OPT=y \
		   CONFIG_FREE_M3_BLOB_MEM=y
else
TARGET_MAKEOPTS := CONFIG_QCA_CLD_WLAN_PROFILE=default
endif

define KernelPackage/$(PKG_NAME)
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=WLAN HOST DRIVER
  DEPENDS := +kmod-wlan-cnss
endef

QCACLD32_LL_MAKEOPTS=  M="$(PKG_BUILD_DIR)/qcacld-3.0" \
			${TARGET_MAKEOPTS} \
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
	$(CP) $(LOCAL_SRC)/platform $(PKG_BUILD_DIR)/
	ln -sf $(PKG_BUILD_DIR)/qcacld-3.0 $(PKG_BUILD_DIR)/../qcacld-3.0
endef

define Build/Compile
	$(MAKE) -j32 -C "$(LINUX_DIR)" $(QCACLD32_LL_MAKEOPTS) \
	modules
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)
	mkdir -p $(1)/$(EXTRA_ADDR)
	mkdir -p $(1)/usr/include/qcacld
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/utils/nlink/inc/wlan_nlink_common.h $(1)/usr/include/qcacld/
endef

define  KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/qcacld-3.0/wlan.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/qcacld-3.0/wlan.ko $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
