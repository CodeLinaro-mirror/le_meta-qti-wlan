include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qcacld32-ll
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=ISC

ifeq ($(TARGET_VARIANT),perf)
  COMPILE_MODE :=perf
else
  COMPILE_MODE :=debug
endif

LOCAL_SRC := $(TOPDIR)/src/wlan
EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra

include $(INCLUDE_DIR)/package.mk

#Default Module dir
BUILD_DIR_CLD := $(PKG_BUILD_DIR)/qcacld-3.0
BUILD_DIR_UPPER := $(PKG_BUILD_DIR)
LOCAL_CLD_FOLDER := $(LOCAL_SRC)/qcacld-3.0
LN_CMD := ln -sf $(PKG_BUILD_DIR)/qcacld-3.0 $(PKG_BUILD_DIR)/../qcacld-3.0
#Default BAZEL DISABLED
ENABLE_BAZEL := n

ifeq ($(BOARD),sdx75)

TARGET_MAKEOPTS := CONFIG_ARCH_SDXPINN=y \
		   CONFIG_CNSS_KIWI_V2=y \
		   CONFIG_QCA_CLD_WLAN_PROFILE=kiwi_v2 \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS2=m \
		   CONFIG_CNSS_GENL=m \
		   CONFIG_CNSS_UTILS=m \
		   CONFIG_WCNSS_MEM_PRE_ALLOC=m \
		   KERNEL_SUPPORTS_NESTED_COMPOSITES=n \
		   WLAN_CTRL_NAME=wlan \
		   WLAN_ROOT_MODULE_SOURCE_PATH=y \
		   CONFIG_FEATURE_SMEM_MAILBOX=y

WLAN_PLATFORM_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss2/Module.symvers
TARGET_MAKEOPTS += KBUILD_EXTRA_SYMBOLS=$(WLAN_PLATFORM_SYMBOLS)
else ifeq ($(BOARD),sdx85)

TARGET_MAKEOPTS := CONFIG_ARCH_SDXKOVA=y \
		   CONFIG_CNSS_KIWI_V2=y \
		   CONFIG_QCA_CLD_WLAN_PROFILE=kiwi_v2 \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS2=m \
		   CONFIG_CNSS_GENL=m \
		   CONFIG_CNSS_UTILS=m \
		   CONFIG_WCNSS_MEM_PRE_ALLOC=m \
		   KERNEL_SUPPORTS_NESTED_COMPOSITES=n \
		   WLAN_CTRL_NAME=wlan \
		   CONFIG_FEATURE_SMEM_MAILBOX=y \
		   WLAN_ROOT_MODULE_SOURCE_PATH=y

WLAN_PLATFORM_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss2/Module.symvers
TARGET_MAKEOPTS += KBUILD_EXTRA_SYMBOLS=$(WLAN_PLATFORM_SYMBOLS)

#ENABLE_BAZEL need to be synced with *.bzl file
#When set to 'n', remove sdxkova support from wlan_qcacld3_modules.bzl as well
ENABLE_BAZEL = y
ifeq ($(ENABLE_BAZEL), y)
  #Module dir for sdx85 with Bazel enabled
  BUILD_DIR_CLD := $(PKG_BUILD_DIR)
  BUILD_DIR_UPPER = $(PKG_BUILD_DIR)/..
  LOCAL_CLD_FOLDER = $(LOCAL_SRC)/qcacld-3.0/*
  LN_CMD =
endif

else ifeq ($(BOARD),sdx35)
TARGET_MAKEOPTS := CONFIG_CNSS_QCA6490=y \
		   CONFIG_WLAN_MEMORY_OPT=y \
		   CONFIG_FREE_M3_BLOB_MEM=y \
		   CONFIG_ARCH_SDXBAAGHA=y \
		   CONFIG_QCA_CLD_WLAN_PROFILE=default \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS2=m \
		   CONFIG_CNSS_UTILS=m \
		   CONFIG_WCNSS_MEM_PRE_ALLOC=m \
		   KERNEL_SUPPORTS_NESTED_COMPOSITES=n

WLAN_PLATFORM_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss2/Module.symvers
TARGET_MAKEOPTS += KBUILD_EXTRA_SYMBOLS=$(WLAN_PLATFORM_SYMBOLS)

else
TARGET_MAKEOPTS := CONFIG_QCA_CLD_WLAN_PROFILE=default
endif

define KernelPackage/$(PKG_NAME)
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=WLAN HOST DRIVER
  DEPENDS := +kmod-wlan-cnss2
endef

QCACLD32_LL_MAKEOPTS=  M="$(BUILD_DIR_CLD)" \
			${TARGET_MAKEOPTS} \
			CONFIG_CNSS_SDIO=n \
			CONFIG_CLD_HL_SDIO_CORE=n

define  KernelPackage/$(PKG_NAME)/Description
	wlan host driver
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_CLD_FOLDER) $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/qca-wifi-host-cmn $(BUILD_DIR_UPPER)/
	$(CP) $(LOCAL_SRC)/fw-api $(BUILD_DIR_UPPER)/
	$(CP) $(LOCAL_SRC)/platform $(BUILD_DIR_UPPER)/
	$(LN_CMD)
endef

define Build/Compile
	$(MAKE) -j32 -C "$(LINUX_DIR)" $(QCACLD32_LL_MAKEOPTS) \
	modules
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)
	mkdir -p $(1)/$(EXTRA_ADDR)
	mkdir -p $(1)/usr/include/qcacld
	$(CP) $(BUILD_DIR_UPPER)/qca-wifi-host-cmn/utils/nlink/inc/wlan_nlink_common.h $(1)/usr/include/qcacld/

ifeq ($(BOARD),sdx75)
# For EasyMesh packages
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/cfg80211_ven_cmd.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ext_ioctl_drv_if.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ieee80211_defines.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ieee80211_external.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/_ieee80211.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ieee80211.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ieee80211_ioctl.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ieee80211_rrm.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ieee80211_wnm_proto.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ieee80211_external_config.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/if_athioctl.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/os_if/son/inc/ol_ath_ucfg.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/uapi/linux/a_types.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcacld-3.0/api/fw/athdefs.h $(1)/usr/include/

	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/qdf/inc/qdf_types.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/qdf/inc/qdf_status.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/qdf/linux/src/i_qdf_types.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/os_if/linux/qca_vendor.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/dp/inc/cdp_txrx_stats_struct.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/dp/inc/cdp_txrx_hist_struct.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/umac/dfs/dispatcher/inc/wlan_dfs_ioctl.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qca-wifi-host-cmn/utils/sys/queue.h $(1)/usr/include/
endif
endef

define  KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(BUILD_DIR_CLD)/wlan.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules
	$(INSTALL_BIN) $(BUILD_DIR_CLD)/wlan.ko $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
