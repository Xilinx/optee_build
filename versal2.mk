################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

# Network support related packages:
BR2_PACKAGE_DHCPCD ?= y
BR2_PACKAGE_ETHTOOL ?= y
BR2_PACKAGE_XINETD ?= y

# SSH Packages :
BR2_PACKAGE_OPENSSH ?= y
BR2_PACKAGE_OPENSSH_SERVER ?= y
BR2_PACKAGE_OPENSSH_KEY_UTILS ?= y

# Openssl binary
BR2_PACKAGE_LIBOPENSSL_BIN ?= y

PLATFORM = AMD Versal Gen 2
OPTEE_OS_PLATFORM = versal2
OPTEE_OS_COMMON_EXTRA_FLAGS = CFG_PKCS11_TA=y CFG_USER_TA_TARGET_pkcs11=ta_arm64 O=out/arm

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/arm-trusted-firmware
U-BOOT_PATH		?= $(ROOT)/u-boot-xlnx
LINUX_PATH		?= $(ROOT)/linux-xlnx
OPTEE_OS_PATH		?= $(ROOT)/optee_os

include common.mk

################################################################################
# Targets
################################################################################

all: tfa optee-os dtbo u-boot linux buildroot
clean: tfa-clean optee-os-clean u-boot-clean linux-clean buildroot-clean dtbo-clean collectartifacts-clean

include toolchain.mk

###############################################################################
# Collect all artifacts to output directory
###############################################################################

OUTPUTDIR = ../$(OPTEE_OS_PLATFORM)_output

collectartifacts:
	mkdir -p $(OUTPUTDIR)
	cp $(U-BOOT_PATH)/u-boot.elf $(OUTPUTDIR)/
	cp $(U-BOOT_PATH)/arch/arm/dts/versal2-*.dtb $(OUTPUTDIR)/
	cp $(TF_A_PATH)/build/versal2/release/bl31/bl31.elf $(OUTPUTDIR)/
	cp $(OPTEE_OS_PATH)/out/arm/core/tee.elf $(OUTPUTDIR)/
	cp $(LINUX_PATH)/arch/arm64/boot/Image $(OUTPUTDIR)
	mkimage -A arm -T ramdisk -C gzip -d ../out-br/images/rootfs.cpio.gz $(OUTPUTDIR)/rootfs.cpio.gz.u-boot

collectartifacts-clean:
	rm -rvf $(OUTPUTDIR)

################################################################################
# ARM Trusted Firmware
################################################################################

TF_A_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
TF_A_FLAGS = PLAT=versal2 CONSOLE=pl011 RESET_TO_BL31=1 SPD=opteed DEBUG=0 MEM_BASE=0x1600000 MEM_SIZE=0x200000 XILINX_OF_BOARD_DTB_ADDR=0x1000 BL32_MEM_BASE=0x1800000 BL32_MEM_SIZE=0x8000000

tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# OP-TEE
#################################################################################

OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_LOG_LEVEL=2 CFG_TEE_TA_LOG_LEVEL=2

optee-os: optee-os-common

optee-os-clean: optee-os-clean-common
	rm -rf ${OPTEE_OS_PATH}/out/

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
U-BOOT_DEFCONFIG_COMMON_FILES := $(U-BOOT_PATH)/configs/amd_versal2_virt_defconfig \
			$(CURDIR)/kconfigs/u-boot_versal2.conf


u-boot-defconfig: $(U-BOOT_DEFCONFIG_COMMON_FILES)
	cd $(U-BOOT_PATH) && \
                ARCH=arm64 \
                scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_COMMON_FILES)

u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH)

u-boot-defconfig-clean:
	rm -f $(U-BOOT_PATH)/.config

u-boot-clean: u-boot-defconfig-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

###############################################################################
# Device-Tree
###############################################################################
dtbo: u-boot
	${LINUX_PATH}/scripts/dtc/dtc -@ -I dts -O dtb -o ./versal2/versal2-memory-reservation.dtbo ./versal2/versal2-memory-reservation.dtso
	@$(foreach dtb,$(wildcard $(U-BOOT_PATH)/arch/arm/dts/versal2-*.dtb), \
		${LINUX_PATH}/scripts/dtc/fdtoverlay -i $(dtb) -o $(dtb) ./versal2/versal2-memory-reservation.dtbo ; \
		echo "Applied overlay to $(dtb)";)

dtbo-clean:
	rm -f ./versal2/versal2-memory-reservation.dtbo

################################################################################
# Linux kernel
################################################################################

LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/xilinx_defconfig \
		$(CURDIR)/kconfigs/versal2.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 -j8

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

###############################################################################
# Buildroot
###############################################################################

BR2_TARGET_GENERIC_ISSUE="OP-TEE embedded distrib for $(PLATFORM)"
BR2_TARGET_ROOTFS_EXT2=y
BR2_PACKAGE_BUSYBOX_WATCHDOG=y

# TF-A, Linux kernel, U-Boot and OP-TEE OS/Client/... are not built from their
# related Buildroot native package.
BR2_TARGET_ARM_TRUSTED_FIRMWARE=n
BR2_LINUX_KERNEL=n
BR2_TARGET_OPTEE_OS=n
BR2_TARGET_UBOOT=n
BR2_PACKAGE_OPTEE_CLIENT=n
BR2_PACKAGE_OPTEE_TEST=n
BR2_PACKAGE_OPTEE_EXAMPLES=n
BR2_PACKAGE_OPTEE_BENCHMARK=n
