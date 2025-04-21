include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-hyfi-bridge-mcc
PKG_RELEASE:=1
PKG_LICENSE:=ISC & GPL-2.0

ifeq ($(TARGET_VARIANT),perf)
  COMPILE_MODE :=perf
else
  COMPILE_MODE :=debug
endif

include $(TOPDIR)/owrt-qti-wlan/include/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_VERSION:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
endif

include $(INCLUDE_DIR)/package.mk

EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra
MSMKERNEL_PATH:=$(TOPDIR)/src/kernel-$(LINUX_VERSION)/kernel_platform/msm-kernel
LOCAL_SRC:=$(TOPDIR)/src/ipq/qca-hyfi-bridge/*
BAZEL_FILES:=
EMESH_SP_HEADERS:=

ENABLE_BAZEL:=n
ifeq ($(BOARD),sdx85)
	ENABLE_BAZEL=y
	BAZEL_FILES=$(TOPDIR)/owrt-qti-wlan/feeds/hyfi/qca-hyfi-bridging/qca-hyfi-bridge-mcc/files/*.b*z*l
	EMESH_SP_HEADERS=$(TOPDIR)/src/ipq/emesh-sp/sp_api.h
endif

QTI_SOFTWARE_CATEGORY:=QTI software

QCAHYFI_BRIDGE_MAKE_OPTS:= \
        CROSS_COMPILE=$(KERNEL_CROSS) \
        ARCH=$(LINUX_KARCH) \
        HYBRID_MC_MLD=1 \
        KERNELPATH=$(LINUX_SRC_DIR) \
        KBUILDPATH=$(LINUX_DIR) \
        KERNELRELEASE=$(LINUX_RELEASE) \
        MDIR=$(PKG_BUILD_DIR) \
        STAGING_DIR=$(STAGING_DIR)

ifeq ($(CONFIG_PACKAGE_qca-plc-serv),y)
        QCAHYFI_BRIDGE_MAKE_OPTS += PLC_SUPPORT_NF=1
endif

CONFIG_HYFI_DISABLE_SSDK_SUPPORT_MCC:=y
ifeq ($(CONFIG_HYFI_DISABLE_SSDK_SUPPORT_MCC),y)
    QCAHYFI_BRIDGE_MAKE_OPTS+= DISABLE_SSDK_SUPPORT=1
endif

ifeq ($(CONFIG_HYD_SUPPORT_MULTICAST_MCC),y)
    QCAHYFI_BRIDGE_MAKE_OPTS+= HYFI_MULTICAST_SUPPORT=1
endif

ifneq ($(CONFIG_PACKAGE_kmod-emesh-sp-mcc),)
    QCAHYFI_BRIDGE_MAKE_OPTS += HYFI_BRIDGE_EMESH_ENABLE=1
endif

QCAHYFI_BRIDGE_MAKE_OPTS += CONFIG_DISABLE_APS_HOOKS=y

QCAHYBRID_MODULE_LIST:=$(PKG_BUILD_DIR)/hyfi-bridging.ko

define KernelPackage/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=Hy-Fi Bridging Netfilter Module
  KCONFIG:= \
    CONFIG_NETFILTER=y \
    CONFIG_BRIDGE_NETFILTER=y
  DEPENDS:=+PACKAGE_kmod-emesh-sp-mcc:kmod-emesh-sp-mcc
  FILES:= $(strip $(QCAHYBRID_MODULE_LIST))
  AUTOLOAD:=$(call AutoLoad,51,hyfi-bridging)
  SUBMENU:=Hy-Fi features
endef

define KernelPackage/$(PKG_NAME)/description
  This package installs the Hy-Fi bridging Netfilter Module
endef

define KernelPackage/$(PKG_NAME)/config
config HYFI_DISABLE_SSDK_SUPPORT
    bool "Disable SSDK support for IPQ platform"
    default y
    help
      This option disable SSDK support
endef

QCA_HYFI_BRIDGE_HEADERS= \
            $(PKG_BUILD_DIR)/hyfi-multicast/mc_api.h \
            $(PKG_BUILD_DIR)/hyfi-netfilter/hyfi_ecm.h \
            $(PKG_BUILD_DIR)/hyfi-netfilter/hyfi_api.h \
            $(PKG_BUILD_DIR)/hyfi-netfilter/hyfi_hash.h

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC) $(PKG_BUILD_DIR)/
ifeq ($(ENABLE_BAZEL),y)
	mkdir -p $(PKG_BUILD_DIR)/emesh-sp/
	$(CP) $(BAZEL_FILES) $(PKG_BUILD_DIR)/
	$(CP) $(EMESH_SP_HEADERS) $(PKG_BUILD_DIR)/emesh-sp/
endif
endef

#ifneq ($(CONFIG_PACKAGE_kmod-qca-hyfi-bridge-mcc),)
define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/hyfibr
	$(foreach header_file,$(QCA_HYFI_BRIDGE_HEADERS), $(CP) $(header_file) $(1)/usr/include/hyfibr;)
endef
#endif

define Build/Compile
	$(CP) $(MSMKERNEL_PATH)/net/bridge/br_private.h $(PKG_BUILD_DIR)/hyfi-netfilter/
	$(CP) $(MSMKERNEL_PATH)/net/bridge/br_private.h $(PKG_BUILD_DIR)/hyfi-multicast/
	$(MAKE) -C $(LINUX_DIR) M=$(PKG_BUILD_DIR) $(strip $(QCAHYFI_BRIDGE_MAKE_OPTS)) \
		KBUILD_EXTRA_SYMBOLS="${STAGING_DIR}/usr/include/emesh-sp/Module.symvers"
endef

define KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules
	$(INSTALL_DIR) $(1)/etc/init.d

	$(INSTALL_BIN) ./files/hyfi-bridging.init $(1)/etc/init.d/hyfi-bridging
	$(INSTALL_BIN) ./files/easymesh_kernel.init $(1)/etc/init.d/easymesh_kernel
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hyfi-bridging.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hyfi-bridging.ko $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
