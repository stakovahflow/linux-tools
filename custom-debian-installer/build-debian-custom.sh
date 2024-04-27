#!/usr/bin/env bash
VERSION='2024-04-27'
# This image is based on debian-live-standard:
# https://cdimage.debian.org/debian-cd/12.5.0-live/amd64/iso-hybrid/debian-live-12.5.0-amd64-standard.iso

ISODESC="dragonsnack custom amd64"
ISONAME="dragonsnack-0.0.2-custom-amd64.iso"
rm -rf "$ISONAME"
rm -rf squashfs-root filesystem.squashfs

echo "Downloading Google Chrome Installer:"
curl -o template/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

echo "Install base utilities:"
apt install -y squashfs-tools syslinux syslinux-efi isolinux xorriso fakeroot

echo "Extracting ISO"
xorriso -osirrox on -indev "debian-live-12.5.0-amd64-standard.iso" -extract / iso && chmod -R +w iso

echo "Copying squashfs from live CD image:"
cp iso/live/filesystem.squashfs .

echo "Extracting root filesystem from squashfs:"
unsquashfs filesystem.squashfs

echo "Setting DNS from current system to new root"
grep "^nameserver" /etc/resolv.conf | tee -a squashfs-root/etc/resolv.conf

echo "Copying default profiles, XFCE4 settings, etc., to new root:"
cp template/profile squashfs-root/etc/
cp template/zshrc squashfs-root/etc/skel/.zshrc
cp template/zlogout squashfs-root/etc/skel/.zlogout
cp template/vimrc squashfs-root/etc/skel/.vimrc
cp template/zshrc squashfs-root/root/.zshrc
cp template/zlogout squashfs-root/root/.zlogout
cp template/vimrc squashfs-root/root/.vimrc

echo "Copying adduser.conf for new user creation to new root:"
cp template/adduser.conf squashfs-root/etc/adduser.conf

echo "Copying XFCE4 panel settings"
mkdir -p squashfs-root/etc/skel/.config
cp -a template/xfce4 squashfs-root/etc/skel/.config/

echo "Copying background images to new root:"
mkdir -p squashfs-root/usr/share/backgrounds/dragonsnack
cp -a template/backgrounds/*.png squashfs-root/usr/share/backgrounds/dragonsnack

echo "Setting locale:"
echo "en_US.UTF-8 UTF-8" | sudo tee -a squashfs-root/etc/locale.gen
echo "LANG=en_US.UTF-8" | sudo tee /etc/default/locale

echo "Copying third-party packages to new root:"
cp template/google-chrome-stable_current_amd64.deb squashfs-root/tmp
cp template/xfce4-docklike-plugin.deb squashfs-root/tmp

CUSTOMIZATIONS="tmp/customizations.sh"
cat >squashfs-root/$CUSTOMIZATIONS <<EOF
https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64
echo "Adding Microsoft VS Code Repository:"
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
sleep 2

echo "Performing base updates:"
apt update
sleep 2

echo "Performing upgrades:"
apt upgrade -y
sleep 2

echo "Installing new packages:"
apt install -y vim bash-completion doas firefox-esr fbautostart fbpager fluxbox fprintd galculator geany gimp gvfs gvfs-backends gvfs-fuse libpam-fprintd lightdm neofetch network-manager-gnome network-manager-openconnect-gnome network-manager-openvpn-gnome network-manager-vpnc-gnome network-manager-l2tp-gnome network-manager-pptp-gnome network-manager-ssh-gnome python3 python3-paramiko python3-pexpect python3-tk xfce4 xfce4-goodies xorg xserver-xorg-input-all xserver-xorg-input-multitouch xserver-xorg-input-synaptics xserver-xorg-video-all zsh zsh-autosuggestions zsh-common zsh-syntax-highlighting transmission-gtk plymouth plymouth-themes git apt-transport-https
sleep 2

echo "Enabling services:"
systemctl enable dbus
systemctl enable NetworkManager
systemctl enable lightdm
sleep 2

echo "Installing Chrome:"
apt install -y /tmp/google-chrome-stable_current_amd64.deb
sleep 2

echo "Installing VSCode:"
apt install -y code
rm -f packages.microsoft.gpg
sleep 2

echo "Installing Docklike plugin for XFCE4:"
apt install -y /tmp/xfce4-docklike-plugin.deb
sleep 2

echo "Changing root shell to zsh"
chsh -s /usr/bin/zsh
sleep 2

echo "Setting editor to vim basic"
update-alternatives --set editor /usr/bin/vim.basic

echo "Adding default desktop background"
mv /etc/alternatives/desktop-background /etc/alternatives/desktop-background-original
ln -s /usr/share/backgrounds/dragonsnack/dragonsnack-bg-1920x1080.png /etc/alternatives/desktop-background

echo "Removing history:"
rm -rf squashfs-root/root/.lesshst squashfs-root/root/.viminfo squashfs-root/root/.zsh_history squashfs-root/root/.bash_history squashfs-root/var/log/*.log

echo "done."
EOF


chmod a+x squashfs-root/$CUSTOMIZATIONS

echo "##############################################################"
echo "Performing chroot operation"
sudo chroot squashfs-root /$CUSTOMIZATIONS
echo "Completed chroot (hopefully it works)"

echo "##############################################################"
echo "Cleaning up"
sleep 2

rm -rf squashfs-root/tmp/*.deb
rm -rf squashfs-root/$CUSTOMIZATIONS
echo "Removing Nameservers:"
sed -i 's/nameserver.*//g' squashfs-root/etc/resolv.conf

sleep 2
echo "compiling squashfs image"
mksquashfs  squashfs-root/ filesystem.squashfs -comp xz -b 1M -noappend

sleep 2
echo "Copying new filesystem to ISO directory"
cp filesystem.squashfs ./iso/live/

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


