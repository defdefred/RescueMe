mkdir iso
mkdir tmp
mkdir iso/boot
mkdir tmp/iso

find /boot > tmp/boot.lst
cpio -o < tmp/boot.lst | cpio -i  --no-absolute-filenames -D iso
UNAMER=$(uname -r)
cp /boot/vmlinuz-${UNAMER} iso/boot/
EARLY_CPIO=$(cpio -t < /boot/initramfs-${UNAMER}.img 2>&1 | egrep '^[0-9]+ blocks' | cut -d \  -f 1)
dd if=/boot/initramfs-${UNAMER}.img of=tmp/initramfs-${UNAMER}.img.gz bs=512 skip=$EARLY_CPIO
dd if=/boot/initramfs-${UNAMER}.img of=iso/boot/initramfs-${UNAMER}.img bs=512 count=$EARLY_CPIO

gzip -t tmp/initramfs-${UNAMER}.img.gz && gzip -dc tmp/initramfs-${UNAMER}.img.gz | cpio -i --no-absolute-filenames -D tmp/iso
cat > tmp/iso/init << EOT
#!/bin/sh
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys
echo "Welcome to your rescue Linux!"
exec /bin/sh
EOT

cd tmp/iso
# Adding ldd
cp /usr/bin/ldd usr/bin/
# Adding ssh
cp /usr/bin/ssh usr/bin/
# Adding ssh  missing lib found with chroot ./iso and ldd /usr/bin/ssh
cp /usr/lib64/libfipscheck.so.1 lib64/
cp /usr/lib64/libutil.so.1 lib64/
# Adding lsblk
cp /usr/bin/lsblk usr/bin/
# Adding lspci
cp /usr/sbin/lspci usr/sbin/
# Adding df
cp /usr/bin/df usr/bin/
# Adding dd
cp /usr/bin/dd usr/bin/

# Grabbing usefull info from running server
ip a > ipa.txt
netstat -rn > netstatrn.txt
lsmod > lsmod.txt

# create the new initramfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs-${UNAMER}.img.gz

cd ../..
# concat with the early initramfs
cat tmp/initramfs-${UNAMER}.img.gz >> iso/boot/initramfs-${UNAMER}.img

# build the rescue iso
grub2-mkrescue -o rescue.iso iso
