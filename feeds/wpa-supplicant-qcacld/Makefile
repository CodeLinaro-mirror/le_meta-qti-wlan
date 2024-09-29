include $(TOPDIR)/rules.mk

PKG_NAME:=wpa-supplicant-qcacld
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_LICENSE:=BSD

LOCAL_SRC := $(TOPDIR)/src/external/wpa_supplicant_8

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -DOPENWRT_BUILD
SUPPLICANT_CONFIG_FILE := $(PKG_BUILD_DIR)/wpa_supplicant/.config

ifeq ($(BOARD),sdx65)
	TARGET_LOCAL_NAME :=sdxlemur
	TARGET_CPPFLAGS += -I$(STAGING_DIR)/usr/include/qmi
	TARGET_ADD_CONFIG := echo -e "\nCONFIG_EAP_PROXY=qmi" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_DUAL_SIM=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_AKA_PRIME:=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_WEP=y" >> $(SUPPLICANT_CONFIG_FILE)
else ifeq ($(BOARD),sdx75)
	TARGET_LOCAL_NAME :=sdxpinn
	TARGET_CPPFLAGS += -I$(STAGING_DIR)/usr/include/qmi
	TARGET_CFLAGS += -DCONFIG_CTRL_IFACE_DIR=\\\"/data/vendor/wifi/wpa_supplicant\\\"
	TARGET_ADD_CONFIG := echo -e "\nCONFIG_EAP_PROXY=qmi" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_DUAL_SIM=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_AKA_PRIME:=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_WEP=y" >> $(SUPPLICANT_CONFIG_FILE)

else ifeq ($(BOARD),sdx85)
	TARGET_LOCAL_NAME :=sdxkova
	TARGET_CPPFLAGS += -I$(STAGING_DIR)/usr/include/qmi
	TARGET_CFLAGS += -DCONFIG_CTRL_IFACE_DIR=\\\"/data/vendor/wifi/wpa_supplicant\\\"
	TARGET_ADD_CONFIG := echo -e "\nCONFIG_EAP_PROXY=qmi" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_DUAL_SIM=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_AKA_PRIME:=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_WEP=y" >> $(SUPPLICANT_CONFIG_FILE)

else ifeq ($(BOARD),sdx35)
	TARGET_LOCAL_NAME :=sdxbaagha
	TARGET_CPPFLAGS += -I$(STAGING_DIR)/usr/include/qmi
	TARGET_CFLAGS += -DCONFIG_CTRL_IFACE_DIR=\\\"/data/vendor/wifi/wpa_supplicant\\\"
	TARGET_ADD_CONFIG := echo -e "\nCONFIG_EAP_PROXY=qmi" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_DUAL_SIM=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_EAP_PROXY_AKA_PRIME:=true" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nCONFIG_WEP=y" >> $(SUPPLICANT_CONFIG_FILE)

else ifeq ($(BOARD),sxrneo)
	TARGET_LOCAL_NAME :=sxrneo
	TARGET_CFLAGS += -DCONFIG_ANDROID_LOG
	TARGET_LDFLAGS += -L$(STAGING_DIR)/usr/lib/ -llog
	TARGET_LDFLAGS += -W1 --no-as-needed
	TARGET_ADD_CONFIG := rm -rf $(STAGING_DIR)/usr/lib/libwpa_supplicant_8_lib.so* && \
		echo -e "\nLIBS +=\"-llog\"" >> $(SUPPLICANT_CONFIG_FILE) && \
		echo -e "\nEXTRALIBS +=\"-llog\"" >> $(SUPPLICANT_CONFIG_FILE)
else
	TARGET_LOCAL_NAME :=misc
endif

TARGET_PATCH_EXIST := $(shell if [ -d "./files/$(TARGET_LOCAL_NAME)" ]; then \
	echo "yes"; else echo "no"; fi)
ifeq ($(TARGET_PATCH_EXIST), yes)
	TARGET_PATCH_PATH := $(TARGET_LOCAL_NAME)
else
	TARGET_PATCH_PATH :=misc
endif

COPY_PATCH_FILES := $(CP) ./files/$(TARGET_PATCH_PATH)/*.patch ./patches/
COPY_CONFIG_FILES := ${INSTALL_DATA} ./files/$(TARGET_PATCH_PATH)/defconfig-qcacld \
			$(SUPPLICANT_CONFIG_FILE)

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI-PACKAGES
  TITLE:=SIGMA DUT
  DEPENDS:= +libnl-tiny +openssl-util +wpa-supplicant-8-lib +qmi +qmi-framework
  USERID:=wifi=1010:wifi=1010 0:wifi=1010
endef

define Package/$(PKG_NAME)/Description
	wpa supplicant
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
	if [ -d "./patches/" ]; then \
		rm -rf ./patches; \
	fi
	mkdir patches
	${COPY_CONFIG_FILES}
	${COPY_PATCH_FILES}
	${TARGET_ADD_CONFIG}
	$(Build/Patch)
endef

TARGET_CPPFLAGS += -I$(STAGING_DIR)/usr/include/libnl3

WPA_SUPPLICANT_MAKEOPTS= $(TARGET_CONFIGURE_OPTS) \
			COPTS="$(TARGET_CFLAGS)" \
			TARGET_CFLAGS="$(TARGET_CFLAGS)" \
			TARGET_LDFLAGS="$(TARGET_LDFLAGS)" \
			TARGET_CPPFLAGS="$(TARGET_CPPFLAGS)" \
			EXTRA_CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS)" \
			 -C $(PKG_BUILD_DIR)/wpa_supplicant

define Build/Compile
        $(MAKE) -j32 $(WPA_SUPPLICANT_MAKEOPTS)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/src/common/wpa_ctrl.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/wpa_supplicant/libwpa_client.so $(STAGING_DIR)/usr/lib/
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/usr/share/acl.d
	$(INSTALL_DIR) $(1)/etc/capabilities
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wpa_supplicant/wpa_supplicant $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wpa_supplicant/wpa_cli $(1)/usr/sbin/
	$(INSTALL_BIN) files/wpa-supplicant_qcacld.init $(1)/etc/init.d/
	$(INSTALL_DATA) ./files/wpa_supplicant_acl.json $(1)/usr/share/acl.d/
	$(INSTALL_DATA) ./files/wpa_supplicant.json $(1)/etc/capabilities/
	$(CP) ./files/wpa_supplicant $(1)/etc/config/
	$(CP) $(PKG_BUILD_DIR)/wpa_supplicant/libwpa_client.so $(1)/usr/lib/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
