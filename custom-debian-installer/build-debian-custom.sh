#!/usr/bin/env bash
VERSION='2025-07-27'
# This image is based on debian-live-standard:
# https://cdimage.debian.org/debian-cd/12.8.0-live/amd64/iso-hybrid/$ISOBASE
ISOBASE="debian-live-12.11.0-amd64-standard.iso"
if [[ ! -f $ISOBASE ]]; then 
	echo "$ISOBASE does not exist. Downloading"; 
	wget https://cdimage.debian.org/debian-cd/12.8.0-live/amd64/iso-hybrid/$ISOBASE -O "$ISOBASE";
else
	echo "$ISOBASE exists. Skipping download"
fi
ls -lh "$ISOBASE"

if [[ $UID -eq 0 ]]; then
	echo "Running $0 as root";
else
	echo "Please run $0 with root permissions (doas/sudo)"; 
	exit
fi 

ISODESC="dragonsnack $VERSION amd64"
ISONAME="dragonsnack-$VERSION-amd64.iso"

SQUISHED="filesystem.squashfs"
SQUISHDIR="squashfs-root"
rm -rf "$ISONAME" "$SQUISHDIR" "$SQUISHED"

DOCKLIKEPKG="xfce4-docklike-plugin.deb"

echo "Install base utilities:"
apt install -y squashfs-tools syslinux syslinux-efi isolinux xorriso fakeroot

echo "Extracting ISO"
xorriso -osirrox on -indev "$ISOBASE" -extract / iso && chmod -R +w iso
sleep 5
cp iso/live/filesystem.squashfs ./"$SQUISHED"

echo "Extracting root filesystem from squashfs:"
unsquashfs "$SQUISHED"

echo "Adding APT Repos:"
echo "Google"
CHROMEAPTSOURCE="template/etc/apt/sources.list.d/google-chrome.list"
CHROMEAPTKEY="template/etc/apt/trusted.gpg.d/google.asc"
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub > "$CHROMEAPTKEY"
echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > "$CHROMEAPTSOURCE"
echo "Code"
VSCODEAPTSOURCE="template/etc/apt/sources.list.d/vscode.list"
VSCODEAPTKEY="template/etc/apt/trusted.gpg.d/microsoft.asc"
wget -q -O - https://packages.microsoft.com/keys/microsoft.asc > "$VSCODEAPTKEY"
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > "$VSCODEAPTSOURCE"
echo "Done"

echo "Setting DNS from current system to new root"
grep "^nameserver" /etc/resolv.conf | tee -a "$SQUISHDIR"/etc/resolv.conf

echo "Copying APT source lists for Chrome & VSCode:"
cp "$CHROMEAPTSOURCE" "$VSCODEAPTSOURCE" "$SQUISHDIR/etc/apt/sources.list.d/"
cp "$CHROMEAPTKEY" "$VSCODEAPTKEY" "$SQUISHDIR/etc/apt/trusted.gpg.d/"

echo "Copying adduser.conf for new user creation to new root:"
cp template/adduser.conf "$SQUISHDIR"/etc/adduser.conf

echo "Copying default profiles, XFCE4 settings, etc., to new root:"
cp template/etc/profile "$SQUISHDIR"/etc/

echo "Copying skel settings to new root:"
mkdir -p "$SQUISHDIR"/etc/skel
cp -a template/etc/skel "$SQUISHDIR"/etc/
cp template/etc/skel/.zshrc "$SQUISHDIR"/root/.zshrc
cp template/etc/skel/.zlogout "$SQUISHDIR"/root/.zlogout
cp template/etc/skel/.vimrc "$SQUISHDIR"/root/.vimrc

echo "Copying background images to new root:"
mkdir -p "$SQUISHDIR"/usr/share/backgrounds/dragonsnack
cp -a template/backgrounds/*.png "$SQUISHDIR"/usr/share/backgrounds/dragonsnack

echo "Setting locale:"
echo "en_US.UTF-8 UTF-8" | sudo tee -a "$SQUISHDIR"/etc/locale.gen
echo "LANG=en_US.UTF-8" | sudo tee "$SQUISHDIR"/etc/default/locale

echo "Copying XFCE4 docklike plugin package to new root:"
cp "template/$DOCKLIKEPKG" "$SQUISHDIR/tmp"

cp template/etc/apt/sources.list "$SQUISHDIR/etc/apt/sources.list"
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
apt install -y vim build-essential doas zsh zsh zsh-autosuggestions zsh-common zsh-syntax-highlighting neofetch network-manager git acpi powertop htop python3 python3-pip python3-paramiko python3-pexpect python3-tk net-tools whois dnsutils openssh-server firmware-linux

echo "Installing nice-to-have packages:"
apt install -y bash-completion firefox-esr fprintd galculator geany gimp gvfs gvfs-backends gvfs-fuse libpam-fprintd lightdm lightdm-settings orca network-manager-gnome network-manager-openconnect-gnome network-manager-openvpn-gnome network-manager-vpnc-gnome network-manager-l2tp-gnome network-manager-pptp-gnome network-manager-ssh-gnome xfce4 xfce4-goodies xorg xserver-xorg-input-all xserver-xorg-input-multitouch xserver-xorg-input-synaptics xserver-xorg-video-all xfce4-appfinder xfce4-dev-tools xfce4-helpers xfce4-panel-profiles xfce4-session xfce4-timer-plugin xfce4-appmenu-plugin xfce4-dict xfce4-indicator-plugin xfce4-places-plugin xfce4-settings xfce4-verve-plugin xfce4-battery-plugin xfce4-diskperf-plugin xfce4-mailwatch-plugin xfce4-power-manager xfce4-smartbookmark-plugin xfce4-wavelan-plugin xfce4-clipman xfce4-mount-plugin xfce4-power-manager-data xfce4-sntray-plugin xfce4-weather-plugin xfce4-clipman-plugin xfce4-eyes-plugin xfce4-mpc-plugin xfce4-power-manager-plugins xfce4-sntray-plugin-common xfce4-whiskermenu-plugin xfce4-cpufreq-plugin xfce4-fsguard-plugin xfce4-netload-plugin xfce4-pulseaudio-plugin xfce4-systemload-plugin xfce4-windowck-plugin xfce4-cpugraph-plugin xfce4-genmon-plugin xfce4-notifyd xfce4-screenshooter xfce4-taskmanager xfce4-xkb-plugin xfce4-datetime-plugin xfce4-goodies xfce4-panel xfce4-sensors-plugin xfce4-terminal transmission-gtk git apt-transport-https docker docker-compose wireshark qemu-system virt-manager xscreensaver xscreensaver-data xscreensaver-data-extra xscreensaver-gl xscreensaver-gl-extra xscreensaver-screensaver-bsod xscreensaver-screensaver-dizzy 

apt install -y code google-chrome-stable 

systemctl disable sshd
systemctl disable libvirtd
systemctl disable docker

echo "Enabling services:"
systemctl enable dbus
systemctl enable NetworkManager
systemctl enable lightdm

echo "Installing Docklike plugin:"
apt install -y "/tmp/$DOCKLIKEPKG"

echo "Clean up here"

#echo "Changing root shell to zsh"
#chsh -s /usr/bin/zsh
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

echo "##############################################################"
echo "Performing chroot operation"
sudo chroot "$SQUISHDIR" "/$CUSTOMIZATIONS"
echo "Completed chroot (hopefully it works)"

echo "Setting LightDM background"
mkdir -p "$SQUISHDIR"/etc/lightdm
up template/etc/lightdm/* "$SQUISHDIR"/etc/lightdm/

echo "Copying local applications:"
mkdir -p "$SQUISHDIR"/usr/local/sbin/
cp template/usr/local/sbin/usbpowermgmt "$SQUISHDIR"/usr/local/sbin/usbpowermgmt
echo "Done."
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
