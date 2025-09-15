#!/bin/bash
set -e

# -------------------------------
# FuelServer Custom ISO Builder
# -------------------------------

ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
ISO_NAME="ubuntu-22.04.5-live-server-amd64.iso"
WORK_DIR="$HOME/custom-iso"
ISO_ROOT="$WORK_DIR/iso-root"
OUTPUT_ISO="$WORK_DIR/FuelServerInstaller.iso"

# -------------------------------
# 1. Install required packages
# -------------------------------
echo "[*] Installing required tools..."
sudo apt update
sudo apt install -y xorriso squashfs-tools cloud-init wget git unzip isolinux syslinux-common openssh-server net-tools

# -------------------------------
# 2. Create work directory
# -------------------------------
if [ ! -d "$WORK_DIR" ]; then
    echo "[*] Creating work directory..."
    sudo mkdir -p "$WORK_DIR"
fi

# -------------------------------
# 3. Download Ubuntu ISO
# -------------------------------
cd "$HOME/custom-iso"
if [ ! -f "$ISO_NAME" ]; then
    echo "[*] Downloading Ubuntu ISO..."
    wget -O "$ISO_NAME" "$ISO_URL"
else
    echo "[*] ISO already downloaded: $ISO_NAME"
fi

# -------------------------------
# 4. Extract ISO contents
# -------------------------------
echo "[*] Preparing work directory..."
# Remove only iso-root to preserve existing files
sudo rm -rf "$ISO_ROOT"
sudo mkdir -p "$ISO_ROOT"

echo "[*] Extracting ISO..."
sudo xorriso -osirrox on -indev "$ISO_NAME" -extract / "$ISO_ROOT"

echo "[*] Generating package and snap lists if needed..."
sudo dpkg --get-selections > "$WORK_DIR/pkglist.txt"
sudo snap list > "$WORK_DIR/snaplist.txt"

# -------------------------------
# 5. Add autoinstall config
# -------------------------------
echo "[*] Adding AutoInstall (cloud-init) config..."
sudo mkdir -p "$ISO_ROOT/nocloud"
sudo cp "$HOME/the-golden-image/AutoInstall/user-data" "$ISO_ROOT/nocloud/user-data"

sudo tee "$ISO_ROOT/nocloud/meta-data" > /dev/null <<'EOF'
instance-id: iid-pos
local-hostname: pos
EOF

# -------------------------------
# 6. Replace GRUB config
# -------------------------------
echo "[*] Replacing GRUB boot configuration..."
sudo cp "$HOME/the-golden-image/AutoInstall/grub.cfg" "$ISO_ROOT/boot/grub/grub.cfg"

# -------------------------------
# 7. Copy ISO creation script
# -------------------------------
echo "[*] Copying verified-iso-creation.sh to home directory..."
sudo cp "$HOME/the-golden-image/AutoInstall/verified-iso-creation.sh" "$HOME/verified-iso-creation.sh"
sudo chmod +x "$HOME/verified-iso-creation.sh"

echo "[*] Setup complete! Now run the ISO creation script:"
echo "    cd $HOME && sudo ./verified-iso-creation.sh"
echo "[*] Custom ISO will be created at: $OUTPUT_ISO"
