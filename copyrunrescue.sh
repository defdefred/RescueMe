#!/bin/sh
set -e # Quit on Error
ERROR="\e[31m"
INFO="\e[33m"
SUCCESS="\e[32m"
STD="\e[m"

echo -e "${INFO}Working directory is $(pwd): [ENTER|Ctrl-C]?${STD}" ; read
mkdir iso
mkdir tmp
mkdir -p iso/boot/grub
mkdir -p tmp/iso

UNAMER=$(uname -r)
echo -e "${SUCCESS}Target is running kernel ${UNAMER}${STD}"
cp /boot/vmlinuz-${UNAMER} iso/boot/

EARLY_CPIO=$(cpio -t < /boot/initramfs-${UNAMER}.img 2>&1 | egrep '^[0-9]+ blocks' | cut -d \  -f 1)
echo -e "${INFO}Expected initramfs is multi-part with cpu microcode, before $EARLY_CPIO blocks${STD}"
echo -e "${INFO}  - Extracting early_cpio...${STD}"
dd if=/boot/initramfs-${UNAMER}.img of=iso/boot/initramfs-${UNAMER}.img bs=512 count=$EARLY_CPIO
echo -e "${INFO}  - Extracting compressed initramfs...${STD}"
dd if=/boot/initramfs-${UNAMER}.img of=tmp/initramfs-${UNAMER}.img.gz bs=512 skip=$EARLY_CPIO

echo -e "${INFO}Analyze initramfs${STD}"
FOUND="NO"
set +e # Continue on Error
for TRY in gloups xz zstd gzip
do
  if [ "$FOUND" == "NO" ]
  then
    echo -e "${INFO}  - $TRY?${STD}"
  else
    break;
  fi
        COMP=$(which $TRY 2>/dev/null)
  if [ "x$COMP" != "x" ]
  then
    $COMP -t tmp/initramfs-${UNAMER}.img.gz
    if [ "$?" == "0" ]
    then
      echo -e "${SUCCESS}YES - initramfs is $COMP compressed${STD}"
      FOUND="YES"
    else
      echo -e "${INFO}NOP - initramfs is not $COMP compressed${STD}"
      COMP=""
    fi
  else
    echo -e "${ERROR}???  - $TRY not installed${STD}"
  fi
done
set -e # Quit on Error

if [ "$FOUND" == "YES" ]
then
  echo -e "${INFO}Uncompress/extract initramfs...${STD}"
  ( cd tmp/iso ; cat ../initramfs-${UNAMER}.img.gz | $COMP -dc | cpio -V -i --no-absolute-filenames )
else
  echo -e "${ERROR}Unable to uncompress/extract initramfs${STD}"
  file tmp/initramfs-${UNAMER}.img.gz
  exit 1
fi

echo -e "${INFO}Overwrite init${STD}"
cat > tmp/iso/init << EOT
#!/bin/sh
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys
echo "Welcome to your rescue Linux!"
exec /bin/sh
EOT

echo -e "${INFO}Adding tools...${STD}"
cd tmp/iso
cp /usr/bin/ldd usr/bin/
cp /usr/bin/lsblk usr/bin/
cp /usr/sbin/lspci usr/sbin/
cp /usr/bin/df usr/bin/
cp /usr/bin/dd usr/bin/
# Adding ssh and missing lib found with chroot ./iso and ldd /usr/bin/ssh
cp /usr/bin/ssh usr/bin/
cp /usr/lib64/libfipscheck.so.1 lib64/
cp /usr/lib64/libutil.so.1 lib64/

echo -e "${INFO}Grabbing usefull info from running server${STD}"
ip a > ipa.txt
netstat -rn > netstatrn.txt
lsmod > lsmod.txt

echo -e "${INFO}Create the new initramfs${STD}"
find . -print0 | cpio --null -oV --format=newc | gzip -9 > ../initramfs-${UNAMER}.img.gz

echo -e "${INFO}Concat with the early initramfs${STD}"
cd ../..
cat tmp/initramfs-${UNAMER}.img.gz >> iso/boot/initramfs-${UNAMER}.img

echo -e "${INFO}Set grub.conf${STD}"
cat > iso/boot/grub/grub.conf << EOT
set default=0
set timeout=10
EOT

if [ -r /sys/firmware/efi ]
then
  cat >> iso/boot/grub/grub.conf << EOT
insmod efi_gop
insmod font
if loadfont /boot/grub/fonts/unicode.pf2
then
        insmod gfxterm
        set gfxmode=auto
        set gfxpayload=keep
        terminal_output gfxterm
fi
EOT
fi

cat >> iso/boot/grub/grub.conf << EOT
menuentry 'myos' --class os {
    insmod gzio
    insmod part_msdos
    linux /boot/vmlinuz-${UNAMER}
    initrd /boot/initramfs-${UNAMER}.img
}
EOT

echo -e "${INFO}Build the rescue iso${STD}"
grub2-mkrescue -o rescue.iso iso && echo -e "${SUCCESS}SUCCESS!${STD}"
