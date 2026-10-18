# Kleaf builds run in a hermetic sandbox whose PATH only contains the
# prebuilt LLVM toolchain, so a bare (GNU) "strip" is not available and
# CROSS_COMPILE is usually empty. Prefer an explicitly passed STRIP, then
# llvm-strip, then $(CROSS_COMPILE)strip; skip stripping if none exists
# (Kleaf strips modules itself during dist anyway).
UWE_STRIP := $(or $(STRIP),$(shell command -v llvm-strip 2>/dev/null),$(shell command -v $(CROSS_COMPILE)strip 2>/dev/null))

# Only drop debug info: a full/unneeded strip can remove symbols the
# module loader needs.
define uwe_strip_ko
	$(if $(UWE_STRIP),$(UWE_STRIP) --strip-debug $(1),@echo "uwe5621: no strip tool found, skipping $(1)")
endef

# sprdwl_ng.ko (WIFI) links against symbols exported by
# uwe5621_bsp_sdio.ko (BSP), so modpost for WIFI needs BSP's
# Module.symvers. It is located at recipe run time (after BSP has been
# built), checking the Kleaf output dir first, then in-tree locations.
UWE_BSP_SYMVERS = $$(for d in "$(OUT_DIR)/$(M)/BSP" "$(KERNEL_SRC)/$(M)/BSP" "$(M)/BSP"; do \
	[ -f "$$d/Module.symvers" ] && { echo "$$d/Module.symvers"; break; }; done)

all: modules

modules:
	$(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(KERNEL_SRC) M=$(M)/BSP CFG_AML_WIFI_DEVICE_UWE5621=y modules
	$(call uwe_strip_ko,${OUT_DIR}/$(M)/BSP/uwe5621_bsp_sdio.ko)
	$(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(KERNEL_SRC) M=$(M)/WIFI CFG_AML_WIFI_DEVICE_UWE5621=y \
		KBUILD_EXTRA_SYMBOLS="$(strip $(KBUILD_EXTRA_SYMBOLS) $(UWE_BSP_SYMVERS))" modules
	$(call uwe_strip_ko,${OUT_DIR}/$(M)/WIFI/sprdwl_ng.ko)

modules_install:
	$(MAKE) INSTALL_MOD_STRIP=1 M=$(M)/BSP -C $(KERNEL_SRC) modules_install
	mkdir -p ${OUT_DIR}/../vendor_lib/modules
	cd ${OUT_DIR}/$(M); find -name "*.ko" -exec cp {} ${OUT_DIR}/../vendor_lib/modules/ \;

