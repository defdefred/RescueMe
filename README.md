# RescueMe
Making a rescueme.iso from running Linux to backup a server with exotic proprietary modules.

## TODO
cat /proc/cmdline


while read DEV reste ; do
  EFI_DEV=$DEV
done < <(lsblk -l -o NAME,FSTYPE,PARTLABEL | egrep "fat.+EFI")

while read DEV SIZE USED FREE PERCENT MOUNT ; do
  EFI_MOUNT=$MOUNT
  EFI_USED=$USED
done < <(df -ml /dev/$EFI_DEV | fgrep "/dev/$EFI_DEV ")

truncate -s 64M rescume.img
fdisk rescume.img 
losetup -P -f --show rescume.img 
mkfs.vfat /dev/loop1p1
mount /dev/loop1p1 /mnt
cp /boot/vmlinuz-6.1.0-3-amd64 /boot/initrd.img-6.1.0-3-amd64 /mnt
mkdir -p /mnt/EFI/BOOT
refind-install --usedefault /dev/loop1p1


root@wize:~# fdisk rescume.img2 << EOT
n
p
1


t
ef
w
EOT
^C
root@wize:~# losetup -P -f --show rescume.img2
/dev/loop3
root@wize:~# mkfs.vfat /dev/loop3p1


pour ssh
rm /dev/tty
ln -s /dev/console /dev/tty

## Needed package
```
xorriso
```
## Grub.cfg
Automatic boot is not working yet, so you have to use:
### grub shell
```
set boot=(cd)
linux (cd)/boot/vmlinuz-4.18.0-147.8.1el.8_1.x86_64
initrd (cd)/boot/initramfs-4.18.0-147.8.1el.8_1.x86_64
boot
```
## How to
### Backup
```
dd if=/dev/sda bs=4096 | /usr/bin/gzip -9 | ssh user@backupserver "dd of=targetserver.gz bs=4096" -o StrictHostKeyChecking=no
```
### Restore
```
ssh user@backupserver "dd if=targetserver.gz bs=4096" -o StrictHostKeyChecking=no | | /usr/bin/gunzip | dd of=/dev/sda bs=4096 
```

## Stupid VM example
rescueme.iso is mounted via vmware virtual cdrom.
(Stupid because VM have snapshots...)
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
This server is using a unusual proprietary drivers for soft raid (LSI megasr). The rescueme.iso is mounted via CIMC KVM virtual dvd/cdrom.
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
https://askubuntu.com/questions/1110651/how-to-produce-an-iso-image-that-boots-only-on-uefi/1111760#1111760
https://askubuntu.com/questions/1289400/remaster-installation-image-for-ubuntu-20-10

