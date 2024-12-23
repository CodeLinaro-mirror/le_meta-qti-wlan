include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=emesh-sp-mcc
PKG_RELEASE:=1
PKG_LICENSE:=ISC

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
LOCAL_SRC:=$(TOPDIR)/src/ipq/emesh-sp/*
BAZEL_FILES:=

ENABLE_BAZEL:=n
ifeq ($(BOARD),sdx85)
	ENABLE_BAZEL=y
	BAZEL_FILES=$(TOPDIR)/owrt-qti-wlan/feeds/emesh-sp-mcc/files/*.b*z*l
endif

define KernelPackage/$(PKG_NAME)
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  URL:=http://www.qualcomm.com
  MAINTAINER:=Qualcomm Technologies, Inc.
  TITLE:=QTI Service Prioritization Support
  KCONFIG:=CONFIG_NETFILTER=y CONFIG_BRIDGE_NETFILTER=y
  FILES:=$(PKG_BUILD_DIR)/emesh-sp.ko
  AUTOLOAD:=$(call AutoLoad,50,emesh-sp)
endef

define KernelPackage/$(PKG_NAME)/description
 This is the kernel module for Service Prioritization in EasyMesh
endef

EMESH_SP_HEADERS= \
            $(PKG_BUILD_DIR)/sp_api.h

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC) $(PKG_BUILD_DIR)/
ifeq ($(ENABLE_BAZEL),y)
	$(CP) $(BAZEL_FILES) $(PKG_BUILD_DIR)/
endif
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/emesh-sp
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include/emesh-sp
	$(foreach header_file,$(EMESH_SP_HEADERS), $(CP) $(header_file) $(1)/usr/include/emesh-sp;)
	$(CP) $(PKG_BUILD_DIR)/Module.symvers $(STAGING_DIR)/usr/include/emesh-sp
endef

define Build/Compile
        $(MAKE) -C "$(LINUX_DIR)" \
                CROSS_COMPILE="$(TARGET_CROSS)" \
                ARCH="$(LINUX_KARCH)" \
                M="$(PKG_BUILD_DIR)" \
                modules
endef

define KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules

	$(INSTALL_BIN) $(PKG_BUILD_DIR)/emesh-sp.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/emesh-sp.ko $(TOPDIR)/bin/targets/$(TARGET_VARIANT)/modules/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
