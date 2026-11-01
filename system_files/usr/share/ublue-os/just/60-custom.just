# FirefoxOS recipes (`ujust --choose`, or e.g. `ujust setup-waydroid`)

# Set up Waydroid for Android apps. TYPE is "vanilla" (no Google) or "gapps"
[group('FirefoxOS')]
setup-waydroid TYPE="vanilla":
    #!/usr/bin/bash
    set -euo pipefail
    case "{{ TYPE }}" in
        vanilla) SYS=VANILLA ;;
        gapps)   SYS=GAPPS ;;
        *) echo "TYPE must be 'vanilla' or 'gapps'"; exit 1 ;;
    esac
    echo "Downloading the Android image (${SYS}). This is several hundred MB..."
    sudo waydroid init -s "${SYS}" -f \
        -c https://ota.waydro.id/system \
        -v https://ota.waydro.id/vendor
    if command -v firewall-cmd >/dev/null && sudo firewall-cmd --state >/dev/null 2>&1; then
        # Let the Android container reach the network
        sudo firewall-cmd --zone=trusted --add-interface=waydroid0 --permanent
        sudo firewall-cmd --zone=trusted --add-port=53/udp --add-port=67/udp --permanent
        sudo firewall-cmd --reload
    fi
    sudo systemctl restart waydroid-container.service
    echo
    echo "Waydroid is ready. Open Start -> Android Apps."
    if [ "${SYS}" = GAPPS ]; then
        echo "To use the Play Store, register this device: ujust waydroid-google-id"
    fi
    read -rp "Press Enter to close" _

# Print the Android ID needed to certify a GAPPS Waydroid install with Google
[group('FirefoxOS')]
waydroid-google-id:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Starting Waydroid session (if needed)..."
    waydroid session start >/dev/null 2>&1 & sleep 10
    sudo waydroid shell -- sh -c "sqlite3 /data/data/*/*/gservices.db \"select * from main where name='android_id';\"" \
        | awk -F'|' '{print "Android ID: " $2}'
    echo "Paste the number at https://www.google.com/android/uncertified then restart Waydroid."

# Remove Waydroid's Android image and all its data
[group('FirefoxOS')]
reset-waydroid:
    #!/usr/bin/bash
    set -euo pipefail
    read -rp "This deletes all Android apps and data. Continue? [y/N] " ans
    [[ "${ans,,}" == y* ]] || exit 0
    waydroid session stop 2>/dev/null || true
    sudo systemctl stop waydroid-container.service
    sudo rm -rf /var/lib/waydroid ~/.local/share/waydroid
    rm -f ~/.local/share/applications/waydroid.*.desktop
    sudo systemctl start waydroid-container.service
    echo "Waydroid reset. Run 'ujust setup-waydroid' to set it up again."

# Download (or update) the Firefox runtime used by web apps
[group('FirefoxOS')]
install-webapp-runtime:
    firefoxpwa runtime install

# Install the Bazaar app store (Flathub) for "Add or Remove Programs"
[group('FirefoxOS')]
install-app-store:
    #!/usr/bin/bash
    set -euo pipefail
    flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y --user flathub io.github.kolunmi.Bazaar
    echo "Installed. Open Start -> Add or Remove Programs."
    read -rp "Press Enter to close" _

# Throw away your desktop customisations and go back to the FirefoxOS defaults
[group('FirefoxOS')]
reset-desktop:
    #!/usr/bin/bash
    set -euo pipefail
    for d in labwc waybar mako foot fuzzel pcmanfm-qt/firefoxos; do
        if [ -e ~/.config/$d ]; then
            mv ~/.config/$d ~/.config/$d.bak-$(date +%s)
            echo "Backed up ~/.config/$d"
        fi
    done
    echo "Done. Log off and back on to apply."

# Copy the default desktop config into ~/.config so you can edit it
[group('FirefoxOS')]
customize-desktop:
    #!/usr/bin/bash
    set -euo pipefail
    for d in labwc waybar; do
        if [ -e ~/.config/$d ]; then echo "~/.config/$d already exists, skipping"; continue; fi
        cp -r /etc/xdg/$d ~/.config/$d
        echo "Copied /etc/xdg/$d -> ~/.config/$d"
    done

# Switch the desktop look: "classic" (blue/green) or "modern" (grey, translucent)
[group('FirefoxOS')]
theme NAME="":
    #!/usr/bin/bash
    if [ -z "{{ NAME }}" ]; then
        echo "Current theme: $(firefoxos-theme)"
        echo "Available: $(firefoxos-theme list | paste -sd ' ')"
        echo "Usage: ujust theme modern"
    else
        firefoxos-theme set "{{ NAME }}"
    fi
