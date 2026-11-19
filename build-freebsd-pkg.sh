#!/bin/sh

set -e

cd /work

cat <<END > /etc/src.conf
WITHOUT_ACCT=YES
WITHOUT_ASAN=YES
WITHOUT_AT=YES
WITHOUT_BHYVE=YES
WITHOUT_BOOT=YES
WITHOUT_BSNMP=YES
WITHOUT_CALENDAR=YES
WITHOUT_LLVM_TARGET_ALL=YES
WITHOUT_CLANG=YES
WITHOUT_CLANG_EXTRAS=YES
WITHOUT_CPP=YES
WITHOUT_CROSS_COMPILER=YES
WITHOUT_DEBUG_FILES=YES
WITHOUT_DIALOG=YES
WITHOUT_DICT=YES
WITHOUT_DMAGENT=YES
WITHOUT_DTRACE=YES
WITHOUT_EE=YES
WITHOUT_EXAMPLES=YES
WITHOUT_FINGER=YES
WITHOUT_FLOPPY=YES
WITHOUT_FORTH=YES
WITHOUT_FREEBSD_UPDATE=YES
WITHOUT_FTP=YES
WITHOUT_GAMES=YES
WITHOUT_GOOGLETEST=YES
WITHOUT_HAST=YES
WITHOUT_HTML=YES
WITHOUT_HYPERV=YES
WITHOUT_ICONV=YES
WITHOUT_INCLUDES=YES
WITHOUT_IPFILTER=YES
WITHOUT_IPFW=YES
WITHOUT_IPSEC_SUPPORT=YES
WITHOUT_ISCI=YES
WITHOUT_KERBEROS=YES
WITHOUT_KERNEL_SYMBOLS=YES
WITHOUT_LDNS=YES
WITHOUT_LIB32=YES
WITHOUT_LLDB=YES
WITHOUT_LOCALES=YES
WITHOUT_LOCATE=YES
WITHOUT_LRP=YES
WITHOUT_LS_COLORS=YES
WITHOUT_MAIL=YES
WITHOUT_MAILWRAPPER=YES
WITHOUT_MAKE=YES
WITHOUT_MAN=YES
WITHOUT_MANCOMPRESS=YES
WITHOUT_MAN_UTILS=YES
WITHOUT_MLX5TOOL=YES
WITHOUT_NETGRAPH=YES
WITHOUT_NLS=YES
WITHOUT_NTP=YES
WITHOUT_OFED=YES
WITHOUT_OPENMP=YES
WITHOUT_PMC=YES
WITHOUT_PPP=YES
WITHOUT_QUOTAS=YES
WITHOUT_RADIUS_SUPPORT=YES
WITHOUT_RESCUE=YES
WITHOUT_RBOOTD=YES
WITHOUT_ROUTED=YES
WITHOUT_SENDMAIL=YES
WITHOUT_SERVICESDB=YES
WITHOUT_SHAREDOCS=YES
WITHOUT_STATS=YES
WITHOUT_TALK=YES
WITHOUT_TESTS=YES
WITHOUT_TOOLCHAIN=YES
WITHOUT_TFTP=YES
WITHOUT_WIRELESS=YES
WITHOUT_WPA_SUPPLICANT_EAPOL=YES
END

cat <<'END' > /work/src/release/Makefile.firecracker
#
# Makefile for creating FreeBSD/Firecracker artifacts
#

CLEANDIRS+=	${TARGET}/firecracker-kern ${TARGET}/firecracker-world

firecracker:	firecracker-freebsd-kern.bin firecracker-freebsd-rootfs.bin

FCKDIR=	${.OBJDIR}/${TARGET}/firecracker-kern
firecracker-freebsd-kern.bin:
.if !defined(DESTDIR) || !exists(${DESTDIR})
	@echo "--------------------------------------------------------------"
	@echo ">>> DESTDIR must point to destination for Firecracker binaries"
	@echo "--------------------------------------------------------------"
	@false
.endif
	mkdir -p ${FCKDIR}
	${MAKE} -C ${WORLDDIR} DESTDIR=${FCKDIR} \
	    KERNCONF=FIRECRACKER TARGET=${TARGET} installkernel
	cp ${FCKDIR}/boot/kernel/kernel ${DESTDIR}/freebsd-kern.bin

FCWDIR=	${.OBJDIR}/${TARGET}/firecracker-world
FCMODDIR=	${FCWDIR}/boot/kernel
FCROOTFSSZ?=	1g
FREEBSD_VERSION?=	15.1-RELEASE
# Userland comes from the FreeBSD base system packages (pkgbase). The repo
# follows the release branch, so it includes security and errata patches.
FCRELEASE=	${FREEBSD_VERSION:C/-.*//}
FCPKGABI?=	FreeBSD:${FCRELEASE:R}:${TARGET_ARCH:U${TARGET}}
FCPKGURL?=	pkg+https://pkg.FreeBSD.org/${FCPKGABI}/base_release_${FCRELEASE:E}
# pkg(8) looks up the fingerprints path inside the root directory given
# with -r, so the keys from the source tree are copied into the new root
# first. FreeBSD-pkg-bootstrap installs the same files there later.
FCPKGKEYS?=	${.CURDIR:H}/share/keys/pkgbase-${FCRELEASE:R}
FCPKGKEYDIR=	/usr/share/keys/pkgbase-${FCRELEASE:R}
FCPKGREPOS=	${.OBJDIR}/${TARGET}/firecracker-repos
# Start from the packages of the minimal set, without the ones that are of
# no use inside a Firecracker VM: there is no loader, no real hardware and
# nobody reads man pages. The set itself is not installed, since it depends
# on all of them.
FCPKGSET?=	FreeBSD-set-minimal
FCPKGEXCLUDE?=	FreeBSD-bootloader FreeBSD-devmatch FreeBSD-efi-tools \
		FreeBSD-firmware-iwm FreeBSD-fwget FreeBSD-hyperv-tools \
		FreeBSD-kernel-man FreeBSD-locales FreeBSD-mandoc \
		FreeBSD-powerd FreeBSD-ppp FreeBSD-vt-data FreeBSD-wpa
# The minimal set has no ssh, pf or jail tools. ipfw provides dnctl(8) for
# the dummynet module.
FCPKGS?=	FreeBSD-ssh FreeBSD-pf FreeBSD-jail FreeBSD-ipfw
FCPKG=		env ASSUME_ALWAYS_YES=yes IGNORE_OSVERSION=yes pkg \
		-o REPOS_DIR=${FCPKGREPOS} -o ABI=${FCPKGABI} -r ${FCWDIR}
firecracker-freebsd-rootfs.bin: firecracker-freebsd-kern.bin
	mkdir -p ${FCWDIR}${FCPKGKEYDIR} ${FCPKGREPOS}
	cp -R ${FCPKGKEYS}/trusted ${FCWDIR}${FCPKGKEYDIR}/
	rm -f ${FCWDIR}${FCPKGKEYDIR}/trusted/Makefile
	printf '%s\n' 'FreeBSD-base: {' \
	    '  url: "${FCPKGURL}",' \
	    '  mirror_type: "srv",' \
	    '  signature_type: "fingerprints",' \
	    '  fingerprints: "${FCPKGKEYDIR}",' \
	    '  enabled: yes' \
	    '}' > ${FCPKGREPOS}/base.conf
	${FCPKG} update -r FreeBSD-base
	${FCPKG} rquery -r FreeBSD-base '%dn' ${FCPKGSET} | \
	    grep -v -x -E '${FCPKGEXCLUDE:ts|}' > ${FCPKGREPOS}/pkglist
	test -s ${FCPKGREPOS}/pkglist
	${FCPKG} install -y -r FreeBSD-base \
	    $$(cat ${FCPKGREPOS}/pkglist) ${FCPKGS}
	rm -rf ${FCWDIR}/var/cache/pkg/* ${FCWDIR}/var/db/pkg/repos
	echo '/dev/ufs/rootfs / ufs rw 1 1' > ${FCWDIR}/etc/fstab
	echo 'hostname="freebsd"' >> ${FCWDIR}/etc/rc.conf
	echo 'ifconfig_vtnet0="inet 172.16.0.2 netmask 255.255.255.0"' >> ${FCWDIR}/etc/rc.conf
	echo 'defaultrouter="172.16.0.1"' >> ${FCWDIR}/etc/rc.conf
	echo 'sshd_enable="YES"' >> ${FCWDIR}/etc/rc.conf
	echo 'sshd_rsa_enable="NO"' >> ${FCWDIR}/etc/rc.conf
	echo 'growfs_enable="YES"' >> ${FCWDIR}/etc/rc.conf
	echo 'nameserver 8.8.8.8' >> ${FCWDIR}/etc/resolv.conf
	sed -i '' -e '/periodic/s/^/#/' ${FCWDIR}/etc/crontab
	pw -R ${FCWDIR} groupadd freebsd -g 1001
	mkdir -p ${FCWDIR}/home/freebsd
	pw -R ${FCWDIR} useradd freebsd -m -M 0755 -w yes -n freebsd \
	    -u 1001 -g 1001 -G 0 -c "FreeBSD User" -d /home/freebsd -s /bin/sh
	pw -R ${FCWDIR} usermod root -w yes
	# Kernel modules. Firecracker boots the kernel without a loader, so
	# nothing is preloaded: these cost no boot time and are loaded on demand
	# by kldload(8), ifconfig(8), zpool(8) or the rc.d scripts.
	mkdir -p ${FCMODDIR}
	cp ${FCKDIR}/boot/kernel/*.ko ${FCMODDIR}/
	kldxref ${FCMODDIR}
	touch ${FCWDIR}/firstboot
	makefs -s ${FCROOTFSSZ} -o label=rootfs -o version=2 -o softupdates=1 \
	    ${DESTDIR}/freebsd-rootfs.bin ${FCWDIR}
END

# Without this, we end up at the mountroot prompt when booting the VM
cat <<END >> /work/src/sys/amd64/conf/FIRECRACKER
options ROOTDEVNAME=\"ufs:/dev/vtbd0\"
END

# Build only the modules that we ship in the rootfs. The kernel itself stays
# the same size, so boot time is unchanged; modules are loaded on demand.
# zfs needs crypto, zlib, xdr and acl_nfs4, pf needs netlink and crypto. All
# of these are already compiled into the FIRECRACKER kernel. dummynet backs
# pf's dnpipe and dnqueue rules. ALTQ queueing is not available, it can only
# be compiled into the kernel.
FIRECRACKER_MODULES="${FIRECRACKER_MODULES:-zfs pf pflog pfsync pflow dummynet if_bridge bridgestp if_epair nullfs fdescfs}"
cat <<END >> /work/src/sys/amd64/conf/FIRECRACKER
makeoptions MODULES_OVERRIDE="${FIRECRACKER_MODULES}"
END

# Disable debug options
cat <<END >> /work/src/sys/amd64/conf/FIRECRACKER
nomakeoptions DEBUG
nomakeoptions WITH_CTF
nooptions INVARIANTS
nooptions INVARIANT_SUPPORT
nooptions WITNESS
nooptions WITNESS_SKIPSPIN
END

# The rootfs is installed with pkg(8), which the VM image may not have yet
pkg -N 2>/dev/null || env ASSUME_ALWAYS_YES=yes pkg bootstrap

make -j$(($(sysctl -n hw.ncpu) + 2)) -C /work/src buildkernel KERNCONF=FIRECRACKER

make -C /work/src/release firecracker DESTDIR=$(pwd) FREEBSD_VERSION="${FREEBSD_VERSION}"
