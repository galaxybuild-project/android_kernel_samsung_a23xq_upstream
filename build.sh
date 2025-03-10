#! /usr/bin/env bash

#
# Rissu Kernel Project
# A special build script for Rissu's kernel
#

# << If unset
[ -z $IS_CI ] && IS_CI=false
[ -z $DO_CLEAN ] && DO_CLEAN=false
[ -z $LTO ] && LTO=none
[ -z $DEFAULT_KSU_REPO ] && DEFAULT_KSU_REPO="https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh"
[ -z $SUSFS_SETUP_SCRIPT ] && SUSFS_SETUP_SCRIPT="https://raw.githubusercontent.com/galaxybuild-project/tools/refs/heads/main/Scripts/KernelSU-SuSFS.sh"
[ -z $DEVICE ] && DEVICE="Unknown"

# special rissu's path. linked to his toolchains
if [ -d /rsuntk ]; then
	export CROSS_COMPILE=/rsuntk/toolchains/aarch64-linux-android/bin/aarch64-linux-android-
	export PATH=/rsuntk/toolchains/clang-20/bin:$PATH
fi

# start of default args
DEFAULT_ARGS="
CONFIG_SECTION_MISMATCH_WARN_ONLY=y
ARCH=arm64
KCFLAGS=-w
CONFIG_BUILD_ARM64_DT_OVERLAY=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y
"

export ARCH=arm64
export CLANG_TRIPLE=aarch64-linux-gnu-
export DTC_EXT=$(pwd)/tools/dtc
export PROJECT_NAME="Wonderful-${PROJECT_VERSION}-${DEVICE}"
export CLANG_VERSION_TEXT=$(clang --version | head -n 1)
if [ "$SUSFS4KSU" = "true" ]; then
    export LOCALVERSION="-wonderful-${PROJECT_VERSION}-SuSFS-qgki+"
elif [ "$KERNELSU" = "true" ]; then
    export LOCALVERSION="-wonderful-${PROJECT_VERSION}-Next-qgki+"
else
    export LOCALVERSION="-wonderful-${PROJECT_VERSION}-Vanilla-gki+"
fi
# end of default args

strip() { # fmt: strip <module>
	llvm-strip $@ --strip-unneeded
}
setconfig() { # fmt: setconfig enable/disable <NAME>
	[ -e $(pwd)/.config ] && config_file="$(pwd)/.config" || config_file="$(pwd)/out/.config"
	if [ -d $(pwd)/scripts ]; then
		./scripts/config --file `echo $config_file` --`echo $1` CONFIG_`echo $2`
	else
		echo "! Folder scripts not found!"
		exit
	fi
}
clone_ak3() {
	[ ! -d $(pwd)/AnyKernel3 ] && git clone https://github.com/rsuntk/AnyKernel3.git --depth=1
	rm -rf AnyKernel3/.git
}
gen_getutsrelease() {
# generate simple c file
if [ ! -e utsrelease.c ]; then
echo "/* Generated file by `basename $0` */
#include <stdio.h>
#ifdef __OUT__
#include \"out/include/generated/utsrelease.h\"
#else
#include \"include/generated/utsrelease.h\"
#endif

char utsrelease[] = UTS_RELEASE;

int main() {
	printf(\"%s\n\", utsrelease);
	return 0;
}" > utsrelease.c
fi
}
pr_invalid() {
	echo -e "[-] Invalid args: $@"
	exit
}
pr_err() {
	echo -e "[-] $@"
	exit
}
pr_info() {
	echo -e "[+] $@"
}
usage() {
	echo -e "Usage: bash `basename $0` <build_target> <-j | --jobs> <(job_count)> <defconfig>"
	printf "\tbuild_target: dirty, kernel, config, clean\n"
	printf "\t-j or --jobs: <int>\n"
	
	[ -d arch/$ARCH/configs ] && printf "\tavailable defconfig: `ls arch/arm64/configs`\n"
	
	echo ""
	printf "NOTE: Run: \texport CROSS_COMPILE=\"<PATH_TO_ANDROID_CC>\"\n"
	printf "\t\texport PATH=\"<PATH_TO_LLVM>\"\n"
	printf "before running this script!\n"
	printf "\n"
	printf "Misc:\n"
	printf "\tPOST_BUILD_CLEAN: Clean post build: (opt:boolean)\n"
	printf "\tLTO: Use Link-time Optimization; options: (opt: none, thin, full)\n"
	printf "\tLLVM: Use all llvm toolchains to build: (opt: 1)\n"
	printf "\tLLVM_IAS: Use llvm integrated assembler: (opt: 1)\n"
	exit;
}

# if first arg starts with "clean"
if [[ "$1" = "clean" ]]; then
	[ $# -gt 1 ] && pr_err "Excess argument, only need one argument."
	pr_info "Cleaning dirs"
	if [ -d $(pwd)/out ]; then
		rm -rf out
	elif [ -f $(pwd)/.config ]; then
		make clean
		make mrproper
	else
		pr_err "No need clean."
	fi
	pr_err "All clean."
elif [[ "$1" = "dirty" ]]; then
	if [ $# -gt 3 ]; then
		pr_err "Excess argument, only need three argument."
	fi	
	pr_err "Starting dirty build"
	FIRST_JOB="$2"
	JOB_COUNT="$3"
	if [ "$FIRST_JOB" = "-j" ] || [ "$FIRST_JOB" = "--jobs" ]; then
		if [ ! -z $JOB_COUNT ]; then
			ALLOC_JOB=$JOB_COUNT
		else
			pr_invalid $3
		fi
	else
		pr_invalid $2
	fi
	make -j`echo $ALLOC_JOB` -C $(pwd) O=$(pwd)/out `echo $DEFAULT_ARGS` 
elif [[ "$1" = "ak3" ]]; then
	if [ $# -gt 1 ]; then
		pr_err "Excess argument, only need one argument."
	fi
	clone_ak3;
else
	[ $# != 4 ] && usage;
fi


if [ "$SUSFS4KSU" = "true" ]; then
    curl -LSs $SUSFS_SETUP_SCRIPT | bash -s next
else
    [ "$KERNELSU" = "true" ] && curl -LSs $DEFAULT_KSU_REPO | bash -s next || pr_info "KernelSU Next is disabled. Add 'KERNELSU=true' or 'export KERNELSU=true' to enable"
fi

BUILD_TARGET="$1"
FIRST_JOB="$2"
JOB_COUNT="$3"
DEFCONFIG="$4"

if [ "$BUILD_TARGET" = "kernel" ]; then
	BUILD="kernel"
elif [ "$BUILD_TARGET" = "defconfig" ]; then
	BUILD="defconfig"
else
	pr_invalid $1
fi

if [ "$FIRST_JOB" = "-j" ] || [ "$FIRST_JOB" = "--jobs" ]; then
	if [ ! -z $JOB_COUNT ]; then
		ALLOC_JOB=$JOB_COUNT
	else
		pr_invalid $3
	fi
else
	pr_invalid $2
fi

if [ ! -z "$DEFCONFIG" ]; then
	BUILD_DEFCONFIG="$DEFCONFIG"
else
	pr_invalid $4
fi

IMAGE="$(pwd)/out/arch/arm64/boot/Image"

if [ "$LLVM" = "1" ]; then
	LLVM_="true"
	DEFAULT_ARGS+=" LLVM=1"
	export LLVM=1
	if [ "$LLVM_IAS" = "1" ]; then
		LLVM_IAS_="true"
		DEFAULT_ARGS+=" LLVM_IAS=1"
		export LLVM_IAS=1
	fi
else
	LLVM_="false"
	if [ "$LLVM_IAS" != "1" ]; then
		LLVM_IAS_="false"
	fi
fi

pr_sum() {
	[ -z $KBUILD_BUILD_USER ] && KBUILD_BUILD_USER="`whoami`"
	[ -z $KBUILD_BUILD_HOST ] && KBUILD_BUILD_HOST="`hostname`"
	
	echo ""
	echo -e "Host Arch: `uname -m`"
	echo -e "Host Kernel: `uname -r`"
	echo -e "Host gnumake: `make -v | grep -e "GNU Make"`"
	echo ""
	echo -e "Linux version: `make kernelversion`"
	echo -e "Kernel builder user: $KBUILD_BUILD_USER"
	echo -e "Kernel builder host: $KBUILD_BUILD_HOST"
	echo -e "Build date: `date`"
	echo -e "Build target: `echo $BUILD`"
	echo -e "Arch: $ARCH"
	echo -e "Defconfig: $BUILD_DEFCONFIG"
	echo -e "Allocated core: $ALLOC_JOB"
	echo ""
	echo -e "LLVM: $LLVM_"
	echo -e "LLVM_IAS: $LLVM_IAS_"
	echo ""
	echo -e "LTO: $LTO"
	echo ""
}

pr_post_build() {
	echo ""
	echo -e "## Build $@ at `date` ##"
	echo ""
	[ "$@" = "failed" ] && exit
}

post_build_clean() {
	if [ -e $AK3 ]; then
		rm -rf $AK3/Image
		rm -rf $AK3/modules/vendor/lib/modules/*.ko
		sed -i "s/do\.modules=.*/do.modules=0/" "$(pwd)/AnyKernel3/anykernel.sh"
		echo "stub" > $AK3/modules/vendor/lib/modules/stub
	fi
	rm getutsrel
	rm utsrelease.c
	# clean out folder
	rm -rf out
	make clean
	make mrproper
}

post_build() {
	if [ -d $(pwd)/.git ]; then
		GITSHA=$(git rev-parse --short HEAD)
	else
		GITSHA="localbuild"
	fi
	
	AK3="$(pwd)/AnyKernel3"
	DATE=$(date +'%Y%m%d%H%M%S')
	if [ "$SUSFS4KSU" = "true" ]; then
		MOD="-SuSFS"
	elif [ "$KERNELSU" = "true" ]; then
		MOD="-Next"
	else
		MOD="-Vanilla"
	fi
	
	ZIP_FMT="Anykernel3-${PROJECT_NAME}-${GITSHA}-${DATE}${MOD}"
	
	clone_ak3;
	if [ -d $AK3 ]; then
		echo "- Creating AnyKernel3"
		gen_getutsrelease;
		if [ -d $(pwd)/out ]; then
			gcc -D__OUT__ -CC utsrelease.c -o getutsrel
		else
			gcc -CC utsrelease.c -o getutsrel
		fi
		UTSRELEASE=$(./getutsrel)
		sed -i "s/kernel\.string=.*/kernel.string=$UTSRELEASE/" "$AK3/anykernel.sh"
		sed -i "s/BLOCK=.*/BLOCK=\/dev\/block\/bootdevice\/by-name\/boot;/" "$AK3/anykernel.sh"
		cp $IMAGE $AK3
		cd $AK3
		zip -r9 ../`echo $ZIP_FMT`.zip *
		# CI will clean itself post-build, so we don't need to clean
		# Also avoiding small AnyKernel3 zip issue!
		if [ "$IS_CI" != "true" ] && [ "$DO_CLEAN" = "true" ]; then
			pr_info "Host is not Automated CI, cleaning dirs"
			post_build_clean;
		fi
		cd ..
		pr_err "Build done. Thanks for using this build script :)"
	fi

	# LKM strip start!
	mkdir ../kernel_obj_tmp && mkdir kernel_obj
        find $(pwd) -type f -name "*.ko" -exec mv {} ../kernel_obj_tmp \;
	TMP_MODLIST=$(find ../kernel_obj_tmp -type f -name "*.ko")
	
        # Start stripping
        for file in $TMP_MODLIST; do
          pr_info "Stripping `basename $file`"
          strip "$file"
        done
        mv ../kernel_obj_tmp/*.ko $(pwd)/kernel_obj/
        
        LKM_FMT="LKM-`echo $DEVICE`_$GITSHA-$DATE"
	tar -czf `echo $LKM_FMT`.tar.gz kernel_obj/*
	rm -rf kernel_obj ../kernel_obj_tmp
}

handle_lto() {
	if [[ "$LTO" = "thin" ]]; then
		pr_info "LTO: Thin"
		setconfig disable LTO_NONE
		setconfig enable LTO
		setconfig enable THINLTO
		setconfig enable LTO_CLANG
		setconfig enable ARCH_SUPPORTS_LTO_CLANG
		setconfig enable ARCH_SUPPORTS_THINLTO
	elif [[ "$LTO" = "full" ]]; then
		pr_info "LTO: Full"
		setconfig disable LTO_NONE
		setconfig enable LTO
		setconfig disable THINLTO
		setconfig enable LTO_CLANG
		setconfig enable ARCH_SUPPORTS_LTO_CLANG
		setconfig enable ARCH_SUPPORTS_THINLTO
	fi
}
# call summary
pr_sum
if [ "$BUILD" = "kernel" ]; then
    echo "Building kernel"

    # Initial defconfig build
    make -j`echo $ALLOC_JOB` -C $(pwd) O=$(pwd)/out `echo $DEFAULT_ARGS` `echo $BUILD_DEFCONFIG`
    
    # Apply SuSFS-specific configurations before final build
    if [ "$SUSFS4KSU" = "true" ]; then
        echo "SuSFS enabled"
        setconfig enable KSU
        setconfig enable KSU_SUSFS
        setconfig enable KSU_SUSFS_SUS_SU
        setconfig enable KSU_SUSFS_HAS_MAGIC_MOUNT
        setconfig enable KSU_SUSFS_SUS_OVERLAYFS
        setconfig enable KSU_SUSFS_ENABLE_LOG
    else
        [ "$KERNELSU" = "true" ] && echo "KernelSU Enabled" && setconfig enable KSU
    fi

    # Apply LTO configuration if enabled
    [ "$LTO" != "none" ] && handle_lto || pr_info "LTO not set"

    # Final kernel build
    make -j`echo $ALLOC_JOB` -C $(pwd) O=$(pwd)/out `echo $DEFAULT_ARGS`

    # Check for successful build
    if [ -e $IMAGE ]; then
        pr_post_build "completed"
        post_build
    else
        pr_post_build "failed"
    fi
fi
