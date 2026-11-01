#!/usr/bin/bash
# FirefoxOS image build script. Runs once inside the Containerfile build.
set -ouex pipefail

FEDORA_VERSION="$(rpm -E %fedora)"
echo "Building FirefoxOS on Fedora ${FEDORA_VERSION}"

### ---------------------------------------------------------------------------
### 1. Third-party repos
### ---------------------------------------------------------------------------

# PWAsForFirefox (firefoxpwa) native component
# https://pwasforfirefox.filips.si/installation/
# Keys are pinned in build_files/keys: packagecloud's repo-metadata key, and
# the upstream author's package-signing key (packagecloud no longer serves it):
#   filips <projects@filips.si>, primary 744007D710DDC8E20673F5452D15DC76BD6B710C,
#   signing subkey 912AD9BE47FEB404 (from keys.openpgp.org / keyserver.ubuntu.com)
install -Dm0644 /ctx/keys/firefoxpwa-repo.asc /etc/pki/rpm-gpg/RPM-GPG-KEY-firefoxpwa-repo
install -Dm0644 /ctx/keys/firefoxpwa-packages.asc /etc/pki/rpm-gpg/RPM-GPG-KEY-firefoxpwa
cat > /etc/yum.repos.d/firefoxpwa.repo <<'EOF'
[firefoxpwa]
name=FirefoxPWA
metadata_expire=7d
baseurl=https://packagecloud.io/filips/FirefoxPWA/rpm_any/rpm_any/$basearch
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-firefoxpwa-repo
       file:///etc/pki/rpm-gpg/RPM-GPG-KEY-firefoxpwa
repo_gpgcheck=1
gpgcheck=1
enabled=1
EOF

### ---------------------------------------------------------------------------
### 2. Packages
### ---------------------------------------------------------------------------

PACKAGES=(
    # --- Wayland desktop: compositor, panel, start menu runtime ---
    labwc
    waybar
    gtk3
    gtk-layer-shell
    python3-gobject
    python3-cairo
    xorg-x11-server-Xwayland
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
    wlrctl                       # "Show desktop" (minimise all windows)
    wlr-randr
    kanshi
    wdisplays                    # Display settings GUI
    swayidle
    swaylock
    wlopm
    mako                         # notifications
    libnotify
    fuzzel                       # "Run..." dialog
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl

    # --- Login screen ---
    greetd
    greetd-selinux
    gtkgreet
    cage

    # --- Desktop icons + file manager ("My Computer") ---
    pcmanfm-qt
    lxqt-qtplugin
    qt6-qtwayland
    qt6-qtsvg                    # SVG wallpapers on the desktop
    lxqt-archiver
    gvfs
    gvfs-mtp
    gvfs-smb
    xdg-user-dirs
    xdg-utils

    # --- Accessories & Control Panel applets ---
    foot                         # Command Prompt
    mousepad                     # Notepad
    galculator                   # Calculator
    ristretto                    # Picture viewer
    htop                         # Task Manager
    fastfetch
    pavucontrol                  # Sounds and Audio Devices
    alsa-tools                   # hda-verb, for `ujust fix-realtek-audio`
    network-manager-applet       # tray icon
    nm-connection-editor         # Network Connections
    blueman                      # Bluetooth
    system-config-printer        # Printers and Faxes
    gnome-disk-utility           # Disk Management
    mate-polkit                  # polkit auth agent
    gnome-keyring
    gnome-keyring-pam

    # --- Look & feel ---
    papirus-icon-theme
    breeze-cursor-theme
    adw-gtk3-theme
    dejavu-sans-fonts
    google-noto-sans-fonts
    google-noto-color-emoji-fonts
    fontawesome-6-free-fonts

    # --- Firefox + web apps ---
    firefox
    firefoxpwa

    # --- Android apps ---
    waydroid
)

dnf5 install -y --setopt=install_weak_deps=False "${PACKAGES[@]}"

# Don't leave third-party repos enabled on the deployed system; updates come
# from rebuilding the image.
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/firefoxpwa.repo

### ---------------------------------------------------------------------------
### 3. Our files (desktop config, start menu, themes, ...)
### ---------------------------------------------------------------------------

cp -avf /ctx/system_files/. /

chmod 0755 /usr/bin/firefoxos-*

# Compile dconf defaults (GTK4/libadwaita apps read these)
dconf update || true

# Make the custom labwc session the only one greetd offers
rm -f /usr/share/wayland-sessions/labwc.desktop

### ---------------------------------------------------------------------------
### 4. Services
### ---------------------------------------------------------------------------

# Login manager: greetd + gtkgreet. Disable anything else a base might enable.
for dm in gdm sddm lightdm; do
    systemctl disable "${dm}.service" 2>/dev/null || true
done
systemctl enable greetd.service
systemctl set-default graphical.target

# Waydroid container manager (images are downloaded by `ujust setup-waydroid`)
systemctl enable waydroid-container.service

### ---------------------------------------------------------------------------
### 5. Branding
### ---------------------------------------------------------------------------

sed -i \
    -e 's/^NAME=.*/NAME="FirefoxOS"/' \
    -e 's/^PRETTY_NAME=.*/PRETTY_NAME="FirefoxOS (Fedora '"${FEDORA_VERSION}"')"/' \
    -e 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="firefoxos"/' \
    /usr/lib/os-release
grep -q '^DEFAULT_HOSTNAME=' /usr/lib/os-release || echo 'DEFAULT_HOSTNAME="firefoxos"' >> /usr/lib/os-release

### ---------------------------------------------------------------------------
### 6. Cleanup
### ---------------------------------------------------------------------------
dnf5 clean all
rm -rf /var/lib/dnf /var/cache/* /tmp/* /run/dnf /run/selinux-policy || true
