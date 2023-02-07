# CopyRunRescue
Making a rescue iso from running Linux to backup exotic driver modules


# Stupid VM example
## Network
```
/usr/sbin/modprobe vmxnet3
/usr/sbin/ip addr add 192.168.0.2/24 dev eth0
```
## Disk
```
/usr/sbin/modprobe vmw_pvscsi
```

# Real UCS C220 M5SX example
This server is using a unusual proprietary drivers for soft raid (LSI megasr)
## grub shell
```
set boot=(cd)
linux (cd)/boot/vmlinuz-4.18.0-147.8.1el.8_1.x86_64
initrd (cd)/boot/initramfs-4.18.0-147.8.1el.8_1.x86_64
boot
```
## modules
```
/usr/sbin/modprobe ixgbe
/usr/sbin/modprobe mlx5_core
/usr/sbin/ifup eth0 
/usr/sbin/ifup eth1
/usr/sbin/ifup eth2
/usr/sbin/ifup eth3
/usr/sbin/ifup eth4
/usr/sbin/ifup eth5
/usr/sbin/ip addr add 192.168.0.2/24 dev eth5
/usr/sbin/ip route add default via 192.168.0.1

/usr/sbin/modprobe ahci
/usr/sbin/modprobe megasr

```


# Usefull links
https://medium.com/@ThyCrow/compiling-the-linux-kernel-and-creating-a-bootable-iso-from-it-6afb8d23ba22
