# CopyRunRescue
Making a rescue iso from running Linux to backup exotic driver modules


# Stupid VM example
## Network
/usr/sbin/modprobe vmxnet3
/usr/sbin/ip addr add 192.168.0.2/24 dev eth0
## Disk
/usr/sbin/modprobe vmw_pvscsi


# Usefull links
https://medium.com/@ThyCrow/compiling-the-linux-kernel-and-creating-a-bootable-iso-from-it-6afb8d23ba22
