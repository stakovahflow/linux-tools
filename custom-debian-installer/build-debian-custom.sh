#!/usr/bin/env bash
VERSION='2024-04-27'
# This image is based on debian-live-standard:
# https://cdimage.debian.org/debian-cd/12.5.0-live/amd64/iso-hybrid/debian-live-12.5.0-amd64-standard.iso
if [[ $UID -eq 0 ]]; then
	echo "Running $0 as root";
else
	echo "Please run $0 with root permissions (doas/sudo)"; 
	exit
fi 

ISODESC="dragonsnack custom amd64"
ISONAME="dragonsnack-0.0.2-custom-amd64.iso"

SQUISHED="filesystem.squashfs"
SQUISHDIR="squashfs-root"
rm -rf "$ISONAME" "$SQUISHDIR" "$SQUISHED"

DOCKLIKEPKG="xfce4-docklike-plugin.deb"

echo "Install base utilities:"
apt install -y squashfs-tools syslinux syslinux-efi isolinux xorriso fakeroot

echo "Extracting ISO"
xorriso -osirrox on -indev "debian-live-12.5.0-amd64-standard.iso" -extract / iso && chmod -R +w iso
sleep 5
cp iso/live/filesystem.squashfs ./"$SQUISHED"

echo "Extracting root filesystem from squashfs:"
unsquashfs "$SQUISHED"

echo "Adding APT Repos:"
CHROMEAPTSOURCE="template/etc/apt/sources.list.d/google-chrome.list"
CHROMEAPTKEY="template/etc/apt/trusted.gpg.d/google.asc"
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub > "$CHROMEAPTKEY"
echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > "$CHROMEAPTSOURCE"

VSCODEAPTSOURCE="template/etc/apt/sources.list.d/vscode.list"
VSCODEAPTKEY="template/etc/apt/trusted.gpg.d/microsoft.asc"
wget -q -O - https://packages.microsoft.com/keys/microsoft.asc > "$VSCODEAPTKEY"
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > "$VSCODEAPTSOURCE"

echo "Setting DNS from current system to new root"
grep "^nameserver" /etc/resolv.conf | tee -a "$SQUISHDIR"/etc/resolv.conf

echo "Copying APT source lists for Chrome & VSCode:"
cp "$CHROMEAPTSOURCE" "$VSCODEAPTSOURCE" "$SQUISHDIR/etc/apt/sources.list.d/"
cp "$CHROMEAPTKEY" "$VSCODEAPTKEY" "$SQUISHDIR/etc/apt/trusted.gpg.d/"

echo "Copying default profiles, XFCE4 settings, etc., to new root:"
cp template/profile "$SQUISHDIR"/etc/
cp template/zshrc "$SQUISHDIR"/etc/skel/.zshrc
cp template/zlogout "$SQUISHDIR"/etc/skel/.zlogout
cp template/vimrc "$SQUISHDIR"/etc/skel/.vimrc
cp template/zshrc "$SQUISHDIR"/root/.zshrc
cp template/zlogout "$SQUISHDIR"/root/.zlogout
cp template/vimrc "$SQUISHDIR"/root/.vimrc

echo "Copying adduser.conf for new user creation to new root:"
cp template/adduser.conf "$SQUISHDIR"/etc/adduser.conf

echo "Copying XFCE4 panel settings"
mkdir -p "$SQUISHDIR"/etc/skel/.config
cp -a template/xfce4 "$SQUISHDIR"/etc/skel/.config/

echo "Copying background images to new root:"
mkdir -p "$SQUISHDIR"/usr/share/backgrounds/dragonsnack
cp -a template/backgrounds/*.png "$SQUISHDIR"/usr/share/backgrounds/dragonsnack

echo "Setting locale:"
echo "en_US.UTF-8 UTF-8" | sudo tee -a "$SQUISHDIR"/etc/locale.gen
echo "LANG=en_US.UTF-8" | sudo tee /etc/default/locale

echo "Copying XFCE4 docklike plugin package to new root:"
cp "template/$DOCKLIKEPKG" "$SQUISHDIR/tmp"

CUSTOMIZATIONS="tmp/customizations.sh"
CUSTOMIZEDSCRIPT="${SQUISHDIR}/tmp/customizations.sh"
echo "Creating embedded script: $CUSTOMIZEDSCRIPT"
cat > "$CUSTOMIZEDSCRIPT" <<EOF
echo "Adding Chrome APT Sources"
echo "Adding VS Code APT Sources"

echo "Performing base updates:"
apt update
echo "Performing upgrades:"
apt upgrade -y
echo "Installing base packages:"
apt install -y vim doas zsh zsh zsh-autosuggestions zsh-common zsh-syntax-highlighting neofetch network-manager git acpi powertop htop
echo "Installing nice-to-have packages:"
apt install -y bash-completion firefox-esr fprintd galculator geany gimp gvfs gvfs-backends gvfs-fuse libpam-fprintd lightdm  network-manager-gnome network-manager-openconnect-gnome network-manager-openvpn-gnome network-manager-vpnc-gnome network-manager-l2tp-gnome network-manager-pptp-gnome network-manager-ssh-gnome python3 python3-paramiko python3-pexpect python3-tk xfce4 xfce4-goodies xorg xserver-xorg-input-all xserver-xorg-input-multitouch xserver-xorg-input-synaptics xserver-xorg-video-all transmission-gtk git apt-transport-https docker docker-compose wireshark qemu-system virt-manager 

apt install -y code google-chrome-stable 

echo "Enabling services:"
systemctl enable dbus
systemctl enable NetworkManager
systemctl enable lightdm

echo "Installing Docklike plugin:"
apt install -y "/tmp/$DOCKLIKEPKG"

echo "Clean up here"

echo "Changing root shell to zsh"
chsh -s /usr/bin/zsh
echo "Setting editor to vim basic"
update-alternatives --set editor /usr/bin/vim.basic

echo "Adding default desktop background"
mv /etc/alternatives/desktop-background /etc/alternatives/desktop-background-original
ln -s /usr/share/backgrounds/dragonsnack/dragonsnack-bg-1920x1080.png /etc/alternatives/desktop-background

echo "done."
EOF


echo "Removing history:"
rm -rf "$SQUISHDIR"/root/.lesshst "$SQUISHDIR"/root/.viminfo "$SQUISHDIR"/root/.zsh_history "$SQUISHDIR"/root/.bash_history "$SQUISHDIR"/var/log/*.log

chmod a+x "$CUSTOMIZEDSCRIPT"
ls -alh "$CUSTOMIZEDSCRIPT"

sleep 2

echo "##############################################################"
echo "Performing chroot operation"
sudo chroot "$SQUISHDIR" "/$CUSTOMIZATIONS"
echo "Completed chroot (hopefully it works)"


echo "##############################################################"
echo "Cleaning up"
sleep 2

rm -rf "$SQUISHDIR"/tmp/*.deb
rm -rf "$SQUISHDIR"/$CUSTOMIZATIONS
echo "Removing Nameservers:"
sed -i 's/nameserver.*//g' "$SQUISHDIR"/etc/resolv.conf

sleep 2
echo "compiling squashfs image"
mksquashfs  "$SQUISHDIR" "$SQUISHED" -comp xz -b 1M -noappend

sleep 2
echo "Copying new filesystem to ISO directory"
cp $SQUISHED ./iso/live/

sleep 2
echo "Generating MD5 Checksum:"
md5sum iso/.disk/info > iso/md5sum.txt
sed -i 's|iso/|./|g' iso/md5sum.txt

sleep 2
echo "Compiling ISO image:"
xorriso -as mkisofs \
   -r -V "$ISODESC" \
   -o "$ISONAME" \
   -J -J -joliet-long -cache-inodes \
   -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
   -b isolinux/isolinux.bin \
   -c isolinux/boot.cat \
   -boot-load-size 4 -boot-info-table -no-emul-boot \
   -eltorito-alt-boot \
   -e boot/grub/efi.img \
   -no-emul-boot -isohybrid-gpt-basdat \
   -isohybrid-apm-hfsplus iso/boot iso

echo "Done."


