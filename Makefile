include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-usbleach

# Version == major.minor.patch
# increase on new functionality (minor) or patches (patch)
PKG_VERSION:=0.1

# Release == build
# increase on changes of translation files or of this Makefile
PKG_RELEASE:=1

PKG_MAINTAINER:=Maxime Guerreiro <punkeel@me.com>

# LuCI specific settings
LUCI_TITLE:=USBleach
LUCI_DEPENDS:=+luasocket +busybox +blkid +openssl-util @USB_SUPPORT kmod-usb-core
LUCI_PKGARCH:=all
# call BuildPackage - OpenWrt buildroot signature

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
endef

define Package/$(PKG_NAME)/description
  USBleach app for LuCI
endef

define Build/Prepare
	for d in luasrc htdocs root; do \
	  if [ -d ./$$$$d ]; then \
	    mkdir -p $(PKG_BUILD_DIR)/$$$$d; \
			$(CP) ./$$$$d/* $(PKG_BUILD_DIR)/$$$$d/; \
	  fi; \
	done
endef

define Build/Configure
endef

define Build/Compile
endef

HTDOCS = /www
LUA_LIBRARYDIR = /usr/lib/lua
LUCI_LIBRARYDIR = $(LUA_LIBRARYDIR)/luci

define Package/$(PKG_NAME)/install
	if [ -d $(PKG_BUILD_DIR)/luasrc ]; then \
	  $(INSTALL_DIR) $(1)$(LUCI_LIBRARYDIR); \
	  $(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)$(LUCI_LIBRARYDIR)/; \
	fi

	if [ -d $(PKG_BUILD_DIR)/htdocs ]; then \
	  $(INSTALL_DIR) $(1)$(HTDOCS); \
	  $(CP) $(PKG_BUILD_DIR)/htdocs/* $(1)$(HTDOCS)/; \
	fi

	if [ -d $(PKG_BUILD_DIR)/root ]; then \
	  $(INSTALL_DIR) $(1)/; \
	  $(CP) $(PKG_BUILD_DIR)/root/* $(1)/; \
	fi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
