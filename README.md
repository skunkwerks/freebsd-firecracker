# Run FreeBSD in a Firecracker VM

This repository contains the scripts and patches needed to boot FreeBSD inside of a Firecracker VM, with an eye towards running FreeBSD in GitHub Actions. My motivating use case is to quickly launch FreeBSD VMs in [rbspy](https://github.com/rbspy/rbspy) CI, which used to be slow and unreliable.

## How it works

To bootstrap the kernel and rootfs images, the CI workflow boots the official FreeBSD VM image directly with QEMU/KVM. We apply small kernel patches to make it bootable in Firecracker on the CPUs that GitHub Actions uses in its runners. The kernel and rootfs are then copied out of the VM and published as artifacts.

## Getting started

If you want to run FreeBSD in GitHub Actions, please have a look at [freebsd-firecracker-action](https://github.com/acj/freebsd-firecracker-action).

You probably won't need to use this repository directly unless you need to make changes to the base image.

## Current status

- [X] Supports FreeBSD 15.1-RELEASE and Firecracker 1.18.0
- [X] Supports Intel and AMD CPUs
- [X] Boots \~instantly in GitHub Actions, excluding download and configuration time
- [X] Optional "pkg-tiny" image with ZFS, pf and bridged vnet jails

## pkg-tiny image

`build-freebsd-pkg.sh` builds the same kernel as `build-freebsd.sh`, plus `zfs`, `pf`, `pflog`, `pfsync`, `pflow`, `dummynet`, `if_bridge`, `bridgestp`, `if_epair`, `nullfs` and `fdescfs` as kernel modules, and installs the userland from the FreeBSD base system packages instead of `base.txz`: the packages of `FreeBSD-set-minimal` without the boot loader, firmware, ppp, locales, man page and hardware support packages, plus `FreeBSD-ssh`, `FreeBSD-pf`, `FreeBSD-jail` and `FreeBSD-ipfw`. It is published as `freebsd-kern-pkg-tiny.bin` and `freebsd-rootfs-pkg-tiny.bin.xz`.

Firecracker boots the kernel directly, without a loader, so no modules are preloaded and boot time is the same as the minimal image. The modules live in `/boot/kernel` and are loaded when first used, e.g. by `zpool`, `ifconfig bridge create`, `service pf onestart` or `kldload`. To change the set, pass `FIRECRACKER_MODULES` to the script.

## Limitations

- FreeBSD 14+ because we need recent Firecracker-related changes
- x86_64 only due to the need for PVH direct boot and lack of nested virtualization support in the GitHub Actions runners (an Azure limitation)

## Contributing

Please be kind. We're all trying to do our best.

If you're having trouble and are confident that it's related to the base images, then please open
an issue. If you'd like to suggest an improvement, please open a PR.

## License

Apache 2.0
