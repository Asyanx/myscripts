#!/bin/bash
# shellcheck disable=SC2154

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

# Kernel building script
WORKDIR="$(pwd)"
KERNEL="$WORKDIR/kernel"

# Cloning Sources
git clone --single-branch --depth=1 https://github.com/Asyanx/kernel-whyred-4.19 -b back $KERNEL && cd $KERNEL
export LOCALVERSION=+🦖
BUILD_EMOTE="${LOCALVERSION#+}"

# Bail out if script fails
set -e
set -o pipefail

# Function to show an informational message
msger()
{
	while getopts ":n:e:" opt
	do
		case "${opt}" in
			n) printf "[*] $2 \n" ;;
			e) printf "[×] $2 \n"; return 1 ;;
		esac
	done
}

cdir()
{
	cd "$1" 2>/dev/null || msger -e "The directory $1 doesn't exists !"
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR="$(pwd)"
BASEDIR="$(basename "$KERNEL_DIR")"

# PATCH KERNELSU & RELEASE VERSION
KSU=0
RELEASE=R1

# The name of the Kernel, to name the ZIP
ZIPNAME="Sea"
if [ $KSU = 1 ]
then
   VER="$RELEASE-KSU"
else
    VER="$RELEASE"
fi

# Build Author
# Take care, it should be a universal and most probably, case-sensitive
AUTHOR="Asyanx"
HOSTR="SICK"

# Architecture
ARCH=arm64

# The name of the device for which the kernel is built
MODEL="Redmi Note 5/PRO"

# The codename of the device
DEVICE="Whyred"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
# Defconfig yang akan dibuild dalam satu kali eksekusi.
# Tambahkan sebanyak yang diperlukan.
DEFCONFIGS=(
    "vendor/whyred-perf_defconfig"
#    "vendor/whyred_perf_defconfig"
)

# Output terpisah untuk setiap defconfig agar hasil build tidak saling bertabrakan.
BUILDS_DIR="$KERNEL_DIR/kernel_builds"


# Specify compiler.
# 'clang' or 'gcc'
COMPILER=clang

# Toolchain Directory defaults to clang-llvm
TC_DIR=$KERNEL_DIR/clang-llvm

# Build modules. 0 = NO | 1 = YES
MODULES=0

# Specify linker.
# 'ld.lld'(default)
LINKER=ld.lld

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=0

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
if [ $PTTG = 1 ]
then
	# Set Telegram Chat ID
	CHATID="-1001910249307"
	TOKEN="5501360993:AAFLnvOrkUpsFJktYu-snmimKNoGk7_WVw8"
fi

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# Files/artifacts
FILES=Image.gz-dtb

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=0

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=0
if [ $SIGN = 1 ]
then
	#Check for java
	if ! hash java 2>/dev/null 2>&1; then
		SIGN=0
		msger -n "you may need to install java, if you wanna have Signing enabled"
	else
		SIGN=1
	fi
fi

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# Verbose build
# 0 is Quiet(default)) | 1 is verbose | 2 gives reason for rebuilding targets
VERBOSE=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first

# shellcheck source=/etc/os-release
export DISTRO=$(source /etc/os-release && echo "${NAME}")
export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
TERM=xterm

#Check Kernel Version
KERVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
WAKTU=$(date +"%F-%S")

#Now Its time for other stuffs like cloning, exporting, etc

 clone()
 {
	echo " "
	if [ $COMPILER = "gcc" ]
	then
		msger -n "|| Cloning GCC 9.3.0 baremetal ||"
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm64.git gcc64
		git clone --depth=1 https://github.com/arter97/arm32-gcc.git gcc32
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
	fi

	if [ $COMPILER = "clang" ]
	then
		git clone --depth=1 https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git ${TC_DIR}
		export LD_LIBRARY_PATH=$TC_DIR/bin/:$LD_LIBRARY_PATH
  		export LLVM=1
		export LLVM_IAS=1
	fi

	msger -n "|| Cloning Anykernel ||"
	git clone --depth=1 https://github.com/Asyanx/AnyKernel3-whyred AnyKernel3

	if [ $BUILD_DTBO = 1 ]
	then
		msger -n "|| Cloning libufdt ||"
		git clone https://android.googlesource.com/platform/system/libufdt "$KERNEL_DIR"/scripts/ufdt/libufdt
	fi
}

##------------------------------------------------------##

exports()
{
	KBUILD_BUILD_USER=$AUTHOR
	KBUILD_BUILD_HOST=$HOSTR
	SUBARCH=$ARCH

	if [ $COMPILER = "clang" ]
	then
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	elif [ $COMPILER = "gcc" ]
	then
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi

	BOT_MSG_URL="https://api.telegram.org/bot$TOKEN/sendMessage"
	BOT_BUILD_URL="https://api.telegram.org/bot$TOKEN/sendDocument"
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER ARCH SUBARCH PATH \
	       KBUILD_COMPILER_STRING BOT_MSG_URL \
	       BOT_BUILD_URL PROCS
}

##---------------------------------------------------------##

tg_post_msg()
{
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------##

tg_post_build()
{
	# Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	# Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5CHECK\`"
}

##----------------------------------------------------------##

build_kernel()
{
	DEFCONFIG="$1"
	BUILD_NAME="${DEFCONFIG%_defconfig}"
	BUILD_DIR="$BUILDS_DIR/$BUILD_NAME"
	BUILD_OUT="$BUILD_DIR/out"
	BUILD_ANYKERNEL="$BUILD_DIR/AnyKernel3"
	BUILD_LOG="$BUILD_DIR/build.log"
	WAKTU=$(date +"%Y%m%d-%H%M%S")
	BUILD_ZIP="$BUILD_DIR/$ZIPNAME-$DEVICE-$BUILD_NAME-$VER-$WAKTU.zip"

	msger -n "|| Preparing $DEFCONFIG ||"


	# Each defconfig gets its own output and AnyKernel directory.
	rm -rf "$BUILD_DIR"
	mkdir -p "$BUILD_DIR"

	if [ "$INCREMENTAL" = 0 ]
	then
		msger -n "|| Cleaning kernel source ||"
		make mrproper
	fi

	# Make a fresh AnyKernel working tree for this defconfig.
	cp -a "$KERNEL_DIR/AnyKernel3" "$BUILD_ANYKERNEL"

	# Reset build-specific variables so consecutive builds do not inherit state.
	MAKE=()

	if [ "$KSU" = 1 ]
	then
		tg_post_msg "<b>$BUILD_EMOTE Sea Build Started</b>%0A<b>Defconfig : </b><code>$DEFCONFIG</code>%0A<b>Docker OS : </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>KernelSU : </b><code>Yes</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>"
	else
		tg_post_msg "<b>$BUILD_EMOTE Sea Build Started</b>%0A<b>Defconfig : </b><code>$DEFCONFIG</code>%0A<b>Docker OS : </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>KernelSU : </b><code>No</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>"
	fi

	msger -n "|| Applying $DEFCONFIG ||"
	make O="$BUILD_OUT" "$DEFCONFIG"

	if [ "$DEF_REG" = 1 ]
	then
		cp "$BUILD_OUT/.config" "arch/arm64/configs/$DEFCONFIG"
		git add "arch/arm64/configs/$DEFCONFIG"
		git commit -m "$DEFCONFIG: Regenerate

This is an auto-generated commit"
	fi

	BUILD_START=$(date +"%s")

	if [ "$COMPILER" = "clang" ]
	then
		MAKE+=(
			CC=clang
			LD=ld.lld \
			AS=llvm-as \
			AR=llvm-ar \
			NM=llvm-nm \
			OBJCOPY=llvm-objcopy \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip \
			CROSS_COMPILE=aarch64-linux-gnu-
			CROSS_COMPILE_ARM32=arm-linux-gnueabi-
		)
	elif [ "$COMPILER" = "gcc" ]
	then
		MAKE+=(
			CROSS_COMPILE_ARM32=arm-eabi-
			CROSS_COMPILE=aarch64-elf-
			AR=aarch64-elf-ar
			OBJDUMP=aarch64-elf-objdump
			STRIP=aarch64-elf-strip
			NM=aarch64-elf-nm
			OBJCOPY=aarch64-elf-objcopy
			LD=aarch64-elf-$LINKER
		)
	fi

	if [ "$SILENCE" = 1 ]
	then
		MAKE+=( -s )
	fi

	msger -n "|| Started Compilation: $DEFCONFIG ||"
	make -k -j"$PROCS" O="$BUILD_OUT" \
		V="$VERBOSE" \
		"${MAKE[@]}" 2>&1 | tee "$BUILD_LOG"

	if [ "$MODULES" = 1 ]
	then
		msger -n "|| Started Compiling Modules: $DEFCONFIG ||"
		make -j"$PROCS" O="$BUILD_OUT" "${MAKE[@]}" modules_prepare
		make -j"$PROCS" O="$BUILD_OUT" "${MAKE[@]}" modules INSTALL_MOD_PATH="$BUILD_OUT/modules"
		make -j"$PROCS" O="$BUILD_OUT" "${MAKE[@]}" modules_install INSTALL_MOD_PATH="$BUILD_OUT/modules"

		if [ -d "$BUILD_OUT/modules" ] && [ -d "$BUILD_ANYKERNEL/modules/system/lib/modules" ]
		then
			find "$BUILD_OUT/modules" -type f -iname '*.ko' \
				-exec cp {} "$BUILD_ANYKERNEL/modules/system/lib/modules/" \;
		fi
	fi

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [ -f "$BUILD_OUT/arch/arm64/boot/$FILES" ]
	then
		msger -n "|| $DEFCONFIG compiled successfully ||"

		if [ "$BUILD_DTBO" = 1 ]
		then
			msger -n "|| Building DTBO: $DEFCONFIG ||"
			tg_post_msg "<code>Building DTBO for $DEFCONFIG..</code>"

			python2 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
				create "$BUILD_OUT/arch/arm64/boot/dtbo.img" \
				--page_size=4096 \
				"$BUILD_OUT/arch/arm64/boot/dts/$DTBO_PATH"
		fi

		gen_zip "$DEFCONFIG"
		return 0
	else
		msger -e "Build failed: $DEFCONFIG"
		if [ "$PTTG" = 1 ]
		then
			tg_post_msg "<b>❌ Sea Build Failed</b>%0A<b>Defconfig : </b><code>$DEFCONFIG</code>%0A<b>Build Time : </b><code>$((DIFF / 60)) minute(s) $((DIFF % 60)) seconds</code>"
			if [ -f "$BUILD_LOG" ]
			then
				tg_post_build "$BUILD_LOG" "*Build log: $DEFCONFIG*"
			fi
		fi
		return 1
	fi
}

##--------------------------------------------------------------##

gen_zip()
{
	DEFCONFIG="$1"
	BUILD_NAME="${DEFCONFIG%_defconfig}"
	BUILD_DIR="$BUILDS_DIR/$BUILD_NAME"
	BUILD_OUT="$BUILD_DIR/out"
	BUILD_ANYKERNEL="$BUILD_DIR/AnyKernel3"
	WAKTU=$(date +"%Y%m%d-%H%M%S")
	ZIP_FINAL="$ZIPNAME-$DEVICE-$BUILD_NAME-$VER-$WAKTU"

	msger -n "|| Zipping $DEFCONFIG into a flashable zip ||"

	mv "$BUILD_OUT/arch/arm64/boot/$FILES" "$BUILD_ANYKERNEL/$FILES"

	if [ "$BUILD_DTBO" = 1 ]
	then
		mv "$BUILD_OUT/arch/arm64/boot/dtbo.img" "$BUILD_ANYKERNEL/dtbo.img"
	fi

	cdir "$BUILD_ANYKERNEL"

	zip -r "$ZIP_FINAL.zip" . -x ".git*" -x "README.md" -x "*.zip"

	if [ "$SIGN" = 1 ]
	then
		if [ "$PTTG" = 1 ]
		then
			msger -n "|| Signing $DEFCONFIG ZIP ||"
			tg_post_msg "<code>Signing $DEFCONFIG ZIP with AOSP keys..</code>"
		fi

		curl -sLo zipsigner-3.0.jar \
			https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar

		java -jar zipsigner-3.0.jar "$ZIP_FINAL.zip" "$ZIP_FINAL-signed.zip"
		rm -f "$ZIP_FINAL.zip"
		ZIP_FINAL="$ZIP_FINAL-signed"
	fi

	mv "$ZIP_FINAL.zip" "$BUILD_DIR/$ZIP_FINAL.zip"

	if [ "$PTTG" = 1 ]
	then
		tg_post_build "$BUILD_DIR/$ZIP_FINAL.zip" \
			"Defconfig: $DEFCONFIG | Build took: $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds"

		tg_post_msg "<b>✅ BUILD SUCCESS</b>%0A<b>Defconfig : </b><code>$DEFCONFIG</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Build Time : </b><code>$((DIFF / 60)) minute(s) $((DIFF % 60)) seconds</code>%0A<b>ZIP : </b><code>$ZIP_FINAL.zip</code>"
	fi

	cd "$KERNEL_DIR"
	msger -n "|| Output: $BUILD_DIR/$ZIP_FINAL.zip ||"
}

##--------------------------------------------------------------##

gen_zip()
{
	msger -n "|| Zipping into a flashable zip ||"
	mv "$BUILD_OUT/arch/arm64/boot/$FILES" AnyKernel3/$FILES
	if [ $BUILD_DTBO = 1 ]
	then
		mv "$BUILD_OUT/arch/arm64/boot/dtbo.img" "$BUILD_ANYKERNEL/dtbo.img"
	fi
	cdir "$BUILD_ANYKERNEL"
	zip -r $ZIPNAME-$DEVICE-$VER-"$WAKTU" . -x ".git*" -x "README.md" -x "*.zip"

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME-$DEVICE-$VER-$WAKTU"

	if [ $SIGN = 1 ]
	then
		## Sign the zip before sending it to telegram
		if [ "$PTTG" = 1 ]
 		then
 			msger -n "|| Signing Zip ||"
			tg_post_msg "<code>Signing Zip file with AOSP keys..</code>"
 		fi
		curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
		java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
		ZIP_FINAL="$ZIP_FINAL-signed"
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_post_build "$ZIP_FINAL.zip" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	fi
	cd "$KERNEL_DIR"
}

clone
exports

mkdir -p "$BUILDS_DIR"

BUILD_FAILED=0

for CURRENT_DEFCONFIG in "${DEFCONFIGS[@]}"
do
	msger -n "|| Starting build: $CURRENT_DEFCONFIG ||"

	if ! build_kernel "$CURRENT_DEFCONFIG"
	then
		msger -e "Build failed: $CURRENT_DEFCONFIG"
		exit 1
	fi
done

msger -n "|| All defconfig builds completed successfully ||"

if [ "$PTTG" = 1 ]
then
	SUMMARY="<b>🏁 All Sea Builds Completed</b>%0A<b>Total Defconfig : </b><code>${#DEFCONFIGS[@]}</code>%0A"
	for CURRENT_DEFCONFIG in "${DEFCONFIGS[@]}"
	do
		SUMMARY+="%0A✅ <code>$CURRENT_DEFCONFIG</code>"
	done
	tg_post_msg "$SUMMARY"
fi

exit 0
