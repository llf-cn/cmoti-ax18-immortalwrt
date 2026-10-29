#
# honk - 基于 eBPF 的透明代理引擎
#
# 上游只发布预编译二进制（aarch64 / x86_64，musl 静态链接），没有 OpenWrt 包配方，
# 因此这里按"下载官方 release tar 包 + 只安装二进制"的方式打包。
#
# 选的是 stock-full 变体：
#   full    = 原生 API + Clash API + 内嵌 doona UI（功能最全，后续换面板不用重编）
#   stock   = 用系统分配器而非 mimalloc（内存峰值更低，路由器更合适）
#   musl    = 静态链接，直接吃 OpenWrt 的 musl，不依赖 glibc
#

include $(TOPDIR)/rules.mk

PKG_NAME:=honk
PKG_VERSION:=0.1.0-beta.3
PKG_RELEASE:=1

PKG_SOURCE:=honk-core-v$(PKG_VERSION)-aarch64-unknown-linux-musl-stock-full.tar.gz
PKG_SOURCE_URL:=https://github.com/daeuniverse/honk/releases/download/v$(PKG_VERSION)
PKG_HASH:=770fe83aa09322ddffe1f16565a681e1ae1fb93db8746bc65db8b5d4d30fa55c

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_PARALLEL:=1

# 上游发的是已 strip 的静态二进制，不要再让交叉 strip / sstrip 动它：
# 二进制里内嵌了 eBPF object，sstrip 会削掉 section header head，有风险。
STRIP:=true
RSTRIP:=true

include $(INCLUDE_DIR)/package.mk

define Package/honk
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=honk eBPF transparent proxy engine
  URL:=https://github.com/daeuniverse/honk
  # kmod-veth: honk 要在 dae0 与 daens 之间拉一对虚拟链路，内核没编 netkit 时回退 veth
  # kmod-nft-queue: 默认开启的 NFQUEUE(320) 首包保持需要 nft_queue + nfnetlink_queue
  DEPENDS:=@TARGET_qualcommax +kmod-veth +kmod-nft-queue
endef

define Package/honk/description
 honk 是 Rust 写的 Linux 透明代理引擎（eBPF 数据面，TCX 挂载）。
 出站支持 SS/Trojan/Hysteria2/TUIC/Juicity/VMess/VLESS 等，配置用 dae 语法。
 注意：上游仍为早期 alpha，不建议用于生产环境。
endef

# 官方 tar 包内是 honk-core-v<ver>-<target>-<variant>/ 顶层目录，strip 掉一层
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	tar -xzf "$(DL_DIR)/$(PKG_SOURCE)" -C "$(PKG_BUILD_DIR)" --strip-components=1
endef

# 预编译二进制，无需编译
define Build/Compile
endef

define Package/honk/conffiles
/etc/honk/config.dae
endef

define Package/honk/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/honk-core $(1)/usr/sbin/honk-core

	$(INSTALL_DIR) $(1)/etc/honk
	$(INSTALL_CONF) ./files/config.dae $(1)/etc/honk/config.dae

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/honk.init $(1)/etc/init.d/honk
endef

$(eval $(call BuildPackage,honk))
