#!/usr/bin/env bash
set -e

#
# This script creates a bootable image and should at some point in the future
# be replaced by the proper NetBSD infrastructure.
#

#
# Source settings if present
#
: ${SETTINGS_MINIX=.settings}
if [ -f "${SETTINGS_MINIX}"  ]
then
	echo "Sourcing settings from ${SETTINGS_MINIX}"
	# Display the content (so we can check in the build logs
	# what the settings contain.
	cat ${SETTINGS_MINIX} | sed "s,^,CONTENT ,g"
	. ${SETTINGS_MINIX}
fi

: ${ARCH=evbearm-el}
: ${OBJ=../obj.${ARCH}}
: ${TOOLCHAIN_TRIPLET=arm-elf32-minix-}
: ${BUILDSH=build.sh}
# Set the number of parallel build jobs the same number of CPU cores.
: ${JOBS=$(nproc)}

: ${SETS="minix-base"}
: ${IMG=minix_arm_sd_rpi.img}

# ARM definitions:
: ${BUILDVARS=-V MKGCCCMDS=yes -V MKLLVM=no}
# These BUILDVARS are for building with LLVM:
#: ${BUILDVARS=-V MKLIBCXX=no -V MKKYUA=no -V MKATF=no -V MKLLVMCMDS=no}

if [ ! -f ${BUILDSH} ]
then
	echo "Please invoke me from the root source dir, where ${BUILDSH} is."
	exit 1
fi

# we create a disk image of about 2 gig's
# for alignment reasons, prefer sizes which are multiples of 4096 bytes
: ${FAT_START=4096}
: ${FAT_SIZE=$((    64*(2**20) - ${FAT_START} ))}
: ${ROOT_SIZE=$((   64*(2**20) ))}
: ${HOME_SIZE=$((  128*(2**20) ))}
: ${USR_SIZE=$((  1792*(2**20) ))}
#: ${IMG_SIZE=$((     2*(2**30) ))} # no need to build an image that big for now
: ${IMG_SIZE=$((    64*(2**20) ))}

# set up disk creation environment
. releasetools/image.defaults
. releasetools/image.functions

# where the kernel & boot modules will be
MODDIR=${DESTDIR}/boot/minix/.temp

echo "Building work directory..."
build_workdir "$SETS"

# IMG might be a block device
if [ -f ${IMG} ]
then
	rm -f ${IMG}
fi
dd if=/dev/zero of=${IMG} bs=512 count=1 seek=$((($IMG_SIZE / 512) -1)) 2>/dev/null

#
# Generate /root, /usr and /home partition images.
#
echo "Writing disk image..."


#
# Write FAT bootloader partition
#
echo " * BOOT"
rm -rf ${ROOT_DIR}/*

# copy over all modules
for i in ${MODDIR}/*
do
	cp $i ${ROOT_DIR}/$(basename $i).elf
done
${CROSS_PREFIX}objcopy ${OBJ}/minix/kernel/kernel -O binary ${ROOT_DIR}/kernel.bin
# create packer
${CROSS_PREFIX}as ${RELEASETOOLSDIR}/rpi-bootloader/bootloader.S -o ${RELEASETOOLSDIR}/rpi-bootloader/bootloader.o
${CROSS_PREFIX}ld ${RELEASETOOLSDIR}/rpi-bootloader/bootloader.o -o ${RELEASETOOLSDIR}/rpi-bootloader/bootloader.elf -Ttext=0x8000 2> /dev/null
${CROSS_PREFIX}objcopy -O binary ${RELEASETOOLSDIR}/rpi-bootloader/bootloader.elf ${ROOT_DIR}/minix_rpi.bin
# copy device trees
cp ${RELEASETOOLSDIR}/rpi-firmware/bcm*.dtb ${ROOT_DIR}



