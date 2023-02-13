#!/bin/sh
set -e # Quit on Error
ERROR="[31m"
INFO="[33m"
SUCCESS="[32m"
STD="[m"

BASE=$(pwd)
echo "${INFO}Working directory is $BASE: [ENTER|Ctrl-C]?${STD}" ; read
mkdir iso
mkdir tmp
mkdir -p iso/boot/grub
mkdir -p tmp/iso

UNAMER=$(uname -r)
echo "${SUCCESS}Target is running kernel ${UNAMER}${STD}"
cp /boot/vmlinuz-${UNAMER} iso/boot/vmlinuz

INITRAMFS=$(find /boot/init*${UNAMER}* | grep -Fv "kdump")
EARLY_CPIO=$(cpio -t < "$INITRAMFS" 2>&1 | ( grep -E '^[0-9]+ blocks' || echo 0 ) | cut -d \  -f 1)
echo "${INFO}Expected initramfs is multi-part with cpu microcode, before $EARLY_CPIO blocks${STD}"
echo "${INFO}  - Extracting early_cpio...${STD}"
dd if="$INITRAMFS" of=iso/boot/initramfs bs=512 count="$EARLY_CPIO"
echo "${INFO}  - Extracting compressed initramfs...${STD}"
dd if="$INITRAMFS" of=tmp/initramfs.gz bs=512 skip="$EARLY_CPIO"

echo "${INFO}Analyze initramfs${STD}"
FOUND="NO"
set +e # Continue on Error
for TRY in xz zstd gzip
do
  if [ "$FOUND" = "NO" ]
  then
    echo "${INFO}  - $TRY?${STD}"
  else
    break;
  fi
  COMP=$(which $TRY 2>/dev/null)
  if [ "x$COMP" != "x" ]
  then
    if [ "$COMP" -t tmp/initramfs.gz ]
    then
      echo "${SUCCESS}    - YES initramfs is $COMP compressed${STD}"
      FOUND="YES"
    else
      echo "${INFO}    - NOP initramfs is not $COMP compressed${STD}"
      COMP=""
    fi
  else
    echo "${ERROR}    - ??? $TRY not installed${STD}"
  fi
done
set -e # Quit on Error

if [ "$FOUND" = "YES" ]
then
  echo "${INFO}Uncompress/extract initramfs...${STD}"
  ( cd tmp/iso ; $COMP -dc ../initramfs.gz | cpio -V -i --no-absolute-filenames )
else
  echo "${ERROR}Unable to uncompress/extract initramfs${STD}"
  file tmp/initramfs.gz
  exit 1
fi

echo "${INFO}Overwrite init${STD}"
cat > tmp/iso/init << EOT
#!/bin/sh
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys
echo "Welcome to RescueMe Linux!"
exec /usr/bin/sh
EOT
chmod +x tmp/iso/init

echo "${INFO}Adding tools...${STD}"
cd tmp/iso || exit 1
for P in $(which ldd) $(which bash) $(which lsblk) $(which lspci) $(which df) $(which dd) $(which ssh)
do
  echo "${INFO}  - $P${STD}"
  cp "$P" ."$P"
  chroot ./ sh /usr/bin/ldd -u "$P" | grep -Fv '/' | while read -r LIB
  do
    echo "${INFO}    - $LIB${STD}"
    find /usr -name "$LIB" -exec echo cp {} .{} \;
  done
done

echo "${INFO}Grabbing usefull info from running server${STD}"
ip a > ipa.txt
ip route > iproute.txt
lsmod > lsmod.txt

echo "${INFO}Create the new initramfs${STD}"
find . -print0 | cpio --null -oV --format=newc | gzip -9 > ../initramfs.gz

echo "${INFO}Concat with the early initramfs${STD}"
cd "$BASE"
cat tmp/initramfs.gz >> iso/boot/initramfs

echo "${INFO}Set grub.conf${STD}"
cat > iso/boot/grub/grub.conf << EOT
set default=0
set timeout=10
menuentry 'myos' --class os {
    insmod gzio
    insmod part_msdos
    linux /boot/vmlinuz
    initrd /boot/initramfs
}
EOT

if [ -r /sys/firmware/efi ]
then
  true
else
  echo "${INFO}Build the rescue iso${STD}"
  GRUB=$(which grub-mkrescue 2>/dev/null || which grub2-mkrescue 2>/dev/null)
  $GRUB -o rescueme.iso iso && echo "${SUCCESS}SUCCESS${STD}"
fi
