# RescueMe
Making a `rescueme.iso` (BIOS with cdrom) or `rescume.img` (EFI with usb) from running Linux to backup a server with exotic proprietary modules.
To be used on the same hardware!

## Needed package for BIOS boot
```
xorriso
```

## Bootloading
Automatic boot is not working yet, so you have to use:
### EFI shell 
```

```
### grub shell ( 'c' keystroke )
```
linux (cd)/boot/vmlinuz
initrd (cd)/boot/initramfs
boot
```
## How to
### prepare some command for later
If existing, a `setup.sh` script will be included in the initramfs.

### Backup
```
dd if=/dev/sdXY bs=4096 | /usr/bin/gzip -9 | ssh -o StrictHostKeyChecking=no user@backupserver "dd of=targetserver.gz bs=4096"
```
### Restore
```
ssh user@backupserver "dd if=targetserver.gz bs=4096" -o StrictHostKeyChecking=no | | /usr/bin/gunzip | dd of=/dev/sdXY bs=4096 
```

## VM example (BIOS and EFI)
`rescueme.iso` is mounted via vmware virtual cdrom OR `rescume.img` is converted to `vmdk` and added to a newly created VM config.

### dd -> vmdk convertion
You can use `qemu-img` to convert the raw `dd` disk image.
```
$ qemu-img convert -pO vmdk ./rescueme.img ./rescueme.vmdk
    (100.00/100%)
```
### Network
```
/usr/sbin/modprobe vmxnet3
/usr/sbin/ip addr add 192.168.0.2/24 dev eth0
```
### Disk
```
/usr/sbin/modprobe vmw_pvscsi
```

## Real UCS C220 M5SX example
This server is using a unusual proprietary drivers for soft raid (LSI megasr). The rescueme.img is mounted via CIMC KVM virtual disk.
### Network
```
/usr/sbin/modprobe ixgbe
/usr/sbin/modprobe mlx5_core
/usr/sbin/ifup eth0 
/usr/sbin/ifup eth1
/usr/sbin/ifup eth2
/usr/sbin/ifup eth3
/usr/sbin/ifup eth4
/usr/sbin/ifup eth5
/usr/sbin/ip addr add 192.168.0.2/24 dev eth2
/usr/sbin/ip route add default via 192.168.0.1
```
### Disk
```
/usr/sbin/modprobe megasr
/usr/sbin/modprobe sd_mod
```
### FS if you need to repair something
```
export PATH=$PATH:/usr/sbin
lvm_scan
lvm vgmknodes
mkdir /new
mount -t xfs /dev/rhel/root /new
mount -t xfs /dev/sda2 /new/boot
mount -t vfat /dev/sda1 /new/boot/efi
mount -t xfs /dev/rhel/home /new/home
chroot /new
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys
echo 1 > /proc/sys/kernel/sysrq
rm -f /dev/tty
ln -s /dev/console /dev/tty
```
https://access.redhat.com/solutions/32726 is helpfull to repair the grub.cfg

## Real Wize thih client
rescueme.iso is "burn" to a usb disk via `dd`.
### Network
```
/usr/sbin/modprobe ixgbe
/usr/sbin/modprobe mlx5_core
/usr/sbin/ifup eth0 
/usr/sbin/ifup eth1
/usr/sbin/ifup eth2
/usr/sbin/ifup eth3
/usr/sbin/ifup eth4
/usr/sbin/ifup eth5
/usr/sbin/ip addr add 192.168.0.2/24 dev eth2
/usr/sbin/ip route add default via 192.168.0.1
```

### Disk
```
/usr/sbin/modprobe ahci
/usr/sbin/modprobe megasr
```

# Usefull links
https://medium.com/@ThyCrow/compiling-the-linux-kernel-and-creating-a-bootable-iso-from-it-6afb8d23ba22

