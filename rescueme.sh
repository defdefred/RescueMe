#!/bin/bash
set -e # Quit on Error
ERROR="\e[31m"
INFO="\e[33m"
SUCCESS="\e[32m"
STD="\e[m"

BASE=$(pwd)
echo -e "${INFO}Working directory is $BASE: [ENTER|Ctrl-C]?${STD}" ; read
mkdir iso
mkdir tmp
mkdir -p iso/boot/grub
mkdir -p tmp/iso

UNAMER=$(uname -r)
echo -e "${SUCCESS}Target is running kernel ${UNAMER}${STD}"
cp /boot/vmlinuz-${UNAMER} iso/boot/vmlinuz

INITRAMFS=$(ls -1rS /boot/init*${UNAMER}* | tail -1)
EARLY_CPIO=$(cpio -t < $INITRAMFS 2>&1 | ( egrep '^[0-9]+ blocks' || echo 0 ) | cut -d \  -f 1)
echo -e "${INFO}Expected initramfs is multi-part with cpu microcode, before $EARLY_CPIO blocks${STD}"
echo -e "${INFO}  - Extracting early_cpio...${STD}"
dd if=$INITRAMFS of=iso/boot/initramfs bs=512 count=$EARLY_CPIO
echo -e "${INFO}  - Extracting compressed initramfs...${STD}"
dd if=$INITRAMFS of=tmp/initramfs.gz bs=512 skip=$EARLY_CPIO

echo -e "${INFO}Analyze initramfs${STD}"
FOUND="NO"
set +e # Continue on Error
for TRY in xz zstd gzip
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
    $COMP -t tmp/initramfs.gz
    if [ "$?" == "0" ]
    then
      echo -e "${SUCCESS}    - YES initramfs is $COMP compressed${STD}"
      FOUND="YES"
    else
      echo -e "${INFO}    - NOP initramfs is not $COMP compressed${STD}"
      COMP=""
    fi
  else
    echo -e "${ERROR}    - ??? $TRY not installed${STD}"
  fi
done
set -e # Quit on Error

if [ "$FOUND" == "YES" ]
then
  echo -e "${INFO}Uncompress/extract initramfs...${STD}"
  ( cd tmp/iso ; cat ../initramfs.gz | $COMP -dc | cpio -V -i --no-absolute-filenames )
else
  echo -e "${ERROR}Unable to uncompress/extract initramfs${STD}"
  file tmp/initramfs.gz
  exit 1
fi

echo -e "${INFO}Overwrite init${STD}"
cat > tmp/iso/init << EOT
#!/bin/sh
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys
echo "Welcome to RescueMe Linux!"
exec /tools/bash
EOT
chmod +x tmp/iso/init

echo -e "${INFO}Adding tools...${STD}"
cd tmp/iso || exit 1
for P in $(which ldd) $(which bash) $(which lsblk) $(which lspci) $(which df) $(which dd) $(which ssh)
do
  echo -e "${INFO}  - $P${STD}"
  cp $P .$P
  chroot ./ sh /usr/bin/ldd -u $P | fgrep -v '/' | while read LIB
  do
    echo -e "${INFO}    - $LIB${STD}"
    find /usr -name "$LIB" -exec echo cp {} .{} \;
  done
done

echo -e "${INFO}Grabbing usefull info from running server${STD}"
ip a > ipa.txt
ip route > iproute.txt
lsmod > lsmod.txt

echo -e "${INFO}Create the new initramfs${STD}"
find . -print0 | cpio --null -oV --format=newc | gzip -9 > ../initramfs.gz

echo -e "${INFO}Concat with the early initramfs${STD}"
cd $BASE
cat tmp/initramfs.gz >> iso/boot/initramfs

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

  cd /boot/efi
  find . -print0 | cpio --null -oV --format=newc > $BASE/tmp/efi.img
  cd $BASE/iso
  cpio -i < $BASE/tmp/efi.img
  cd $BASE

fi

cat >> iso/boot/grub/grub.conf << EOT
menuentry 'myos' --class os {
    insmod gzio
    insmod part_msdos
    linux /boot/vmlinuz
    initrd /boot/initramfs
}
EOT

echo -e "${INFO}Build the rescue iso${STD}"
#GRUB=$(which grub-mkrescue 2>/dev/null || which grub2-mkrescue 2>/dev/null)
#$GRUB -o rescueme.iso iso && echo -e "${SUCCESS}SUCCESS${STD}"
grub2-mkimage -o rescume.img iso
