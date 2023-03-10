#!/bin/sh
set -e # Quit on Error
#ERROR=""
#INFO=""
#SUCCESS=""
#STD=""
ESC=""
ERROR="$ESC[31m"
INFO="$ESC[33m"
SUCCESS="$ESC[32m"
STD="$ESC[m"

BASE=$(pwd)
echo "${INFO}Working directory is $BASE: [ENTER|Ctrl-C]?${STD}" ; read -r WAIT
mkdir iso
mkdir tmp
mkdir out
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
    "$COMP" -t tmp/initramfs.gz
    if [ "$?" = "0" ]
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
export PATH=$PATH:/usr/sbin
mkdir -p /proc /sys
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys
echo 1 > /proc/sys/kernel/sysrq
rm -f /dev/tty
ln -s /dev/console /dev/tty
echo " ----------------------------"
echo "| Welcome to RescueMe Linux! |"
echo " ----------------------------"
exec /usr/bin/sh
EOT
chmod +x tmp/iso/init

echo "${INFO}Adding tools...${STD}"
cd tmp/iso || exit 1
for P in $(which ldd) $(which lsblk) $(which lspci) $(which df) $(which dd) $(which ssh)  $(which chmod)  $(which fuser) $(which bash)
do
  if [ -r ."$P" ]
  then
    echo "${INFO}  - $P already present${STD}"
  else
    echo "${INFO}  - $P coping...${STD}"
    cp "$P" ."$P"
    chroot ./ /usr/bin/sh /usr/bin/ldd -u "$P" | grep -Fv '/' | grep -Fv 'Unused' | while read -r LIB
    do
      echo "${INFO}    - $LIB${STD}"
      find /usr -name "$LIB" -exec cp {} .{} \;
    done
  fi
done

echo "${INFO}Adding setup.sh if existing${STD}"
if [ -f "$BASE/setup.sh" ]
then
  cp  "$BASE/setup.sh" .
  chmod +x setup.sh
  echo "${SUCCESS}Ok${STD}"
else
  echo "${ERROR}Not found${STD}"
fi

echo "${INFO}Grabbing usefull info from running server${STD}"
ip a > ipa.txt
ip route > iproute.txt
lsmod > lsmod.txt
cat /proc/cmdline > proccmdline.txt

echo "${INFO}Create the new initramfs${STD}"
find . -print0 | cpio --null -oV --format=newc | gzip -9 > ../initramfs.gz

echo "${INFO}Concat with the early initramfs${STD}"
cd "$BASE"
cat tmp/initramfs.gz >> iso/boot/initramfs

echo "${INFO}Set grub.conf${STD}"
cat > iso/boot/grub/grub.conf << EOT
set default=0
set timeout=10
menuentry 'RescueMe' --class os {
  savedefault
  insmod gzio
  insmod part_msdos
  linux /boot/vmlinuz
  initrd /boot/initramfs
}
EOT

if [ -r /sys/firmware/efi ]
then
  echo "${INFO}Analyse EFI${STD}"
  read -r EFI_DEV reste << EOT
$(lsblk -l -o NAME,FSTYPE,PARTLABEL | grep -E "fat.+EFI")
EOT
  read -r DEV SIZE EFI_USED FREE PERCENT EFI_MOUNT << EOT
$(df -ml /dev/$EFI_DEV | fgrep "/dev/$EFI_DEV ")
EOT
  echo "${INFO}$EFI_MOUNT ($EFI_DEV) need ${EFI_USED}M"${STD}
  read -r BOOT_USED reste << EOT
$(du -sm iso)
EOT
  DISK_SIZE=$(( "$EFI_USED" + "$BOOT_USED" + 3 ))
  echo "${INFO}Disk rescueme.img need ${DISK_SIZE}M${STD}"
  echo "${INFO}  - Disk creation${STD}"
  truncate -s ${DISK_SIZE}M out/rescueme.img
  fdisk out/rescueme.img  >/dev/null << EOT
n
p
1

+${EFI_USED}M
t
ef
n
p
2


w
EOT
  echo "${INFO}  - Formating partition${STD}"
  read -r LOOP <<EOT
$(losetup -P -f --show out/rescueme.img)
EOT
  mkfs.vfat "$LOOP"p1
  mkfs.ext2 "$LOOP"p2
  echo "${INFO}  - Mounting partition${STD}"
  mkdir tmp/efi
  mkdir tmp/boot
  mount "$LOOP"p1 tmp/efi
  mount "$LOOP"p2 tmp/boot
  echo "${INFO}  - EFI duplication${STD}"
  cd $EFI_MOUNT
  tar cf - . | ( cd $BASE/tmp/efi ; tar xfv - )
  cd $BASE
  echo "${INFO}  - Kernel and Initramfs${STD}"
  cd iso/boot
  tar cf - . | ( cd $BASE/tmp/boot ; tar xfv - )
  cd $BASE
  echo "${INFO}  - Umounting partition${STD}"
  umount tmp/efi
  umount tmp/boot
  losetup -D "$LOOP" && echo "${SUCCESS}SUCCESS${STD}"
else
  echo "${INFO}Build the rescue iso${STD}"
  GRUB=$(which grub-mkrescue 2>/dev/null || which grub2-mkrescue 2>/dev/null)
  $GRUB -o out/rescueme.iso iso && echo "${SUCCESS}SUCCESS${STD}"
fi

echo "Please copy the result from "out" folder and remorvre the temporary files if not needed (rm -rf out iso tmp)"
