include $(TOPDIR)/rules.mk

PKG_NAME:=hostapd-daemon
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

LOCAL_SRC := $(TOPDIR)/src/external/wpa_supplicant_8

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -DOPENWRT_BUILD
HOSTAPD_CONFIG_FILE := $(PKG_BUILD_DIR)/hostapd/.config

ifeq ($(BOARD),sdx65)
	TARGET_ADD_CONFIG += echo -e "\nCONFIG_WEP=y" >> $(HOSTAPD_CONFIG_FILE)
	TARGET_LOCAL_NAME :=sdxlemur
else ifeq ($(BOARD),sdx75)
	TARGET_ADD_CONFIG += echo -e "\nCONFIG_WEP=y" >> $(HOSTAPD_CONFIG_FILE)
	TARGET_LOCAL_NAME :=sdxpinn
else ifeq ($(BOARD),sdx35)
	TARGET_ADD_CONFIG += echo -e "\nCONFIG_WEP=y" >> $(HOSTAPD_CONFIG_FILE)
	TARGET_LOCAL_NAME :=sdxbaagha
else ifeq ($(BOARD),sxrneo)
	TARGET_ADD_CONFIG += echo -e "\nLIBS_c +=-llog" >> $(HOSTAPD_CONFIG_FILE) && \
			     echo -e "\nLIBS +=-llog" >> $(HOSTAPD_CONFIG_FILE)
	TARGET_LOCAL_NAME :=sxrneo
	TARGET_CFLAGS += -DCONFIG_ANDROID_LOG
else
	TARGET_LOCAL_NAME :=$(BOARD)
endif

TARGET_PATCH_EXIST := $(shell if [ -d "./files/$(TARGET_LOCAL_NAME)" ]; then \
	echo "yes"; else echo "no"; fi)
ifeq ($(TARGET_PATCH_EXIST), yes)
	TARGET_PATCH_PATH := $(TARGET_LOCAL_NAME)
else
	TARGET_PATCH_PATH :=misc
endif

COPY_PATCH_FILES := $(CP) ./files/$(TARGET_PATCH_PATH)/*.patch ./patches/
COPY_CONFIG_FILES := ${INSTALL_DATA} ./files/$(TARGET_PATCH_PATH)/defconfig-qcacld  $(HOSTAPD_CONFIG_FILE)
INCLUDE_LIBNL :=echo -e "\nCFLAGS +=\"-I${STAGING_DIR}/usr/include/libnl3\"" >> $(HOSTAPD_CONFIG_FILE)

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI-PACKAGES
  TITLE:=HOSTAPD
  DEPENDS:= +libnl +openssl-util +wpa-supplicant-8-lib +liblog
endef
# DEPENDS += pkgconfig since no exist

define Package/$(PKG_NAME)/Description
	hostapd
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
	if [ -d "./patches/" ]; then \
		rm -rf ./patches; \
	fi
	mkdir patches
	${COPY_CONFIG_FILES}
	${INCLUDE_LIBNL}
	${TARGET_ADD_CONFIG}
	${COPY_PATCH_FILES}
	$(Build/Patch)
endef

TARGET_CPPFLAGS += -I$(STAGING_DIR)/usr/include/libnl3
TARGET_CFLAGS += -lnl-3

HOSTAPD_MAKEOPTS= $(TARGET_CONFIGURE_OPTS) \
		COPTS="$(TARGET_CFLAGS)" \
		TARGET_CFLAGS="$(TARGET_CFLAGS)" \
		TARGET_LDFLAGS="$(TARGET_LDFLAGS)" \
		-C $(PKG_BUILD_DIR)/hostapd

define Build/Compile
        $(MAKE) -j32 $(HOSTAPD_MAKEOPTS)
endef

define Build/InstallDev
	@true
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd_cli $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
