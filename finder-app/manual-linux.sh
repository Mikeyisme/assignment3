#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=${1:-/tmp/aeld}
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

echo "Using output directory: ${OUTDIR}"
mkdir -p ${OUTDIR} || { echo "Failed to create output directory"; exit 1; }

cd "$OUTDIR"

# Clone the Linux kernel source if not already present
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING LINUX KERNEL VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone --depth 1 --single-branch --branch ${KERNEL_VERSION} ${KERNEL_REPO} linux-stable
fi

cd linux-stable
echo "Checking out kernel version ${KERNEL_VERSION}"
git checkout ${KERNEL_VERSION}

# Build the kernel
echo "Building the kernel"
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all

# Copy the kernel image to the output directory
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}


echo "Kernel build complete."

# Create the root filesystem staging area
echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]; then
    echo "Deleting existing rootfs directory"
    sudo rm -rf ${OUTDIR}/rootfs
fi

mkdir -p rootfs/{bin,sbin,etc,proc,sys,dev,lib,usr,home,tmp,var}
mkdir -p rootfs/lib64

# Clone and build BusyBox
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]; then
    echo "Cloning BusyBox"
    git clone git://busybox.net/busybox.git
fi

cd busybox
git checkout ${BUSYBOX_VERSION}
make distclean
make defconfig
make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

echo "BusyBox build complete."

# Add library dependencies
echo "Adding library dependencies"
SYSROOT=$(${CROSS_COMPILE}gcc --print-sysroot)
cp -a ${SYSROOT}/lib/ld-* rootfs/lib/
cp -a ${SYSROOT}/lib64/ld-* rootfs/lib64/
cp -a ${SYSROOT}/lib/libm.so.* rootfs/lib/
cp -a ${SYSROOT}/lib64/libm.so.* rootfs/lib64/
cp -a ${SYSROOT}/lib/libresolv.so.* rootfs/lib/
cp -a ${SYSROOT}/lib64/libresolv.so.* rootfs/lib64/
cp -a ${SYSROOT}/lib/libc.so.* rootfs/lib/
cp -a ${SYSROOT}/lib64/libc.so.* rootfs/lib64/

# Create device nodes
echo "Creating device nodes"
sudo mknod -m 666 rootfs/dev/null c 1 3
sudo mknod -m 600 rootfs/dev/console c 5 1

# Build and install writer utility
echo "Building writer utility"
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

cp writer ${OUTDIR}/rootfs/home/

# Copy finder related scripts and files
echo "Copying finder application scripts"
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/home/

# Modify finder-test.sh to reference the correct assignment.txt path
sed -i 's|\.\./conf/assignment.txt|/home/assignment.txt|g' ${FINDER_APP_DIR}/finder-test.sh
cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/

# Copy autorun-qemu.sh script
cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# Set ownership to root
echo "Setting ownership to root"
sudo chown -R root:root ${OUTDIR}/rootfs

# Create initramfs
echo "Creating initramfs.cpio.gz"
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio

echo "Initramfs and kernel setup complete."
