include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wlan-dts-oss
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=BSD-3-Clause

LOCAL_SRC := $(TOPDIR)/src/vendor/qcom/opensource/wlan/wlan-devicetree
TEACHPACK_DTBOS_PATH := $(TOPDIR)/build_dir/$(TARGET_DIR_NAME)/linux-$(BOARD)$(if $(SUBTARGET),_$(SUBTARGET))/techpack-dtbos

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

ifeq ($(BOARD),echo)
MAKE_OPTS += CONFIG_ARCH_ECHO=y
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
	mkdir -p $(TEACHPACK_DTBOS_PATH)
	$(CP) $(PKG_BUILD_DIR)/*.dtbo $(TEACHPACK_DTBOS_PATH)/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
