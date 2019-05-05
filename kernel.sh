 #
 # Script For Building Android arm64 Kernel 
 #
 # Copyright (c) 2018-2019 Panchajanya1999 <rsk52959@gmail.com>
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
 
#! /bin/sh

#Kernel building script

KERNEL_DIR=$PWD

function colors {
	blue='\033[0;34m' cyan='\033[0;36m'
	yellow='\033[0;33m'
	red='\033[0;31m'
	nocol='\033[0m'
}


function clone {
	echo " "
	echo "{yellow}★★Cloning GCC Toolchain from Android GoogleSource ..{nocol}"
	sleep 2
	git clone --depth 5 --no-single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9.git
	git clone --depth 5 --no-single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9

	#Workaround to remove deprecation spam of gcc
	cd aarch64-linux-android-4.9
	git reset --hard 22f053ccdfd0d73aafcceff3419a5fe3c01e878b
	cd $KERNEL_DIR/arm-linux-androideabi-4.9
	git reset --hard 42e5864a7d23921858ca8541d52028ff88acb2b6
	cd $KERNEL_DIR

	echo "{blue}★★GCC cloning done{nocol}"
	sleep 2
	echo "{yellow}★★Cloning Clang 7 sources (r349610){nocol}"
	git clone --depth 1 https://github.com/Panchajanya1999/clang-llvm.git -b 8.0
	echo "{blue}★★Clang Done, Now Its time for AnyKernel ..{nocol}"
	git clone --depth 1 --no-single-branch https://github.com/Panchajanya1999/AnyKernel2.git -b violet
	echo "{cyan}★★Cloning Kinda Done..!!!{nocol}"
}

function exports {
	export KBUILD_BUILD_USER="ci"
	export KBUILD_BUILD_HOST="panchajanya"
	export ARCH=arm64
	export SUBARCH=arm64
	export KBUILD_COMPILER_STRING=$($KERNEL_DIR/clang-llvm/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	LD_LIBRARY_PATH=$KERNEL_DIR/clang-llvm/lib64:$LD_LIBRARY_PATH
	export LD_LIBRARY_PATH
	PATH=$KERNEL_DIR/clang-llvm/bin/:$KERNEL_DIR/aarch64-linux-android-4.9/bin/:$PATH
	export PATH
}

function tg_post_msg {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" -d text="$1"
}

function tg_post_build {
	curl -F chat_id="$2" -F document=@"$1" $BOT_BUILD_URL
}

function build_kernel {
	#better checking defconfig at first
	if [ -f $KERNEL_DIR/arch/arm64/configs/vendor/violet-perf_defconfig ]
	then 
		DEFCONFIG=vendor/violet-perf_defconfig
	else
		echo "{red}Defconfig Mismatch..!!!{nocol}"
		tg_post_msg "☠☠Defconfig Mismatch..!! Build Failed..!!👎👎" "$GROUP_ID"
		echo "{red}Exiting in 5 seconds...{nocol}"
		sleep 5
		exit
	fi
	
	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	tg_post_msg "★★ Build Started on $(uname) $(uname -r) ★★" "$GROUP_ID"
	tg_post_msg "**Device : **`Redmi Note 7 Pro(violet)`" "$GROUP_ID"
	make -j8 O=out \
		CC=$KERNEL_DIR/clang-llvm/bin/clang \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE_ARM32=$KERNEL_DIR/arm-linux-androideabi-4.9/bin/arm-linux-androideabi- \
		CROSS_COMPILE=$KERNEL_DIR/aarch64-linux-android-4.9/bin/aarch64-linux-android- 2>&1 | tee logcat.txt
	BUILD_END=$(date +"%s")
	BUILD_TIME=$(date +"%Y%m%d-%T")
	DIFF=$((BUILD_END - BUILD_START))	
}

function check_img {
	if [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ]
	then 
		echo -e "{yellow}Kernel Built Successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds..!!{nocol}"
		tg_post_msg "👍👍Kernel Built Successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds..!!" "$GROUP_ID"
		#gen_changelog //Stop posting changelogs as of now
		gen_zip
	else 
		echo -e "{red}Kernel failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds..!!{nocol}"
		tg_post_msg "☠☠Kernel failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds..!!" "$GROUP_ID"
		tg_post_build "logcat.txt" "$GROUP_ID"
	fi	
}

function gen_changelog {
	tg_post_msg "★★ ChangeLog --
	$(git log --oneline --decorate --color --pretty=%s --first-parent -7)" "$GROUP_ID"
}

function gen_zip {
	if [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ]
	then 
		echo "{yellow}Zipping Files..{nocol}"
		mv $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb AnyKernel2/Image.gz-dtb
		cd AnyKernel2
		zip -r9 azure-VIOLET-$BUILD_TIME * -x .git README.md
		tg_post_build "azure-VIOLET-$BUILD_TIME.zip" "$GROUP_ID"
		cd ..
	fi
}

colors
clone
exports
build_kernel
check_img
