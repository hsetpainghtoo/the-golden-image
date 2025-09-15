#!/bin/bash
set -e

# -------------------------------
# FuelServer Custom ISO Builder
# -------------------------------
# Detect real user home, even if run with sudo
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(eval echo "~$SUDO_USER")
else
  USER_HOME="$HOME"
fi

# Load variables from .env
set -a
source "$USER_HOME/the-golden-image/AutoInstall/.env"
set +a

ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
ISO_NAME="ubuntu-22.04.5-live-server-amd64.iso"
WORK_DIR="$USER_HOME/custom-iso"
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
cd "$USER_HOME/custom-iso"
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
sudo cp "$USER_HOME/the-golden-image/AutoInstall/user-data.yml" "$ISO_ROOT/nocloud/user-data"

sudo tee "$ISO_ROOT/nocloud/meta-data" > /dev/null <<'EOF'
instance-id: iid-pos
local-hostname: pos
EOF

# -------------------------------
# 6. Replace GRUB config
# -------------------------------
echo "[*] Replacing GRUB boot configuration..."
sudo cp "$USER_HOME/the-golden-image/AutoInstall/grub.cfg" "$ISO_ROOT/boot/grub/grub.cfg"

# -------------------------------
# 7. Rename "boot" folder name to "BOOT" inside "EFI" because you can't boot without renaming it
# -------------------------------
echo "[*] Renaming \"boot\" folder to \"BOOT\" inside \"EFI\"..."
sudo mv "$ISO_ROOT/EFI/boot" "$ISO_ROOT/EFI/BOOT"

# -------------------------------
# 8. Cloning Projects Git Repositories (frontend and backend)
# -------------------------------
echo "[*] Cloning Projects Git Repositories..."
sudo mkdir -p "$ISO_ROOT/custom-configs"
sudo git clone https://${USERNAME}:${PASSWORD}@github.com/digitalengineeringtech/fuel-management-frontend-nextjs.git "$ISO_ROOT/custom-configs/frontend"
sudo git clone https://${USERNAME}:${PASSWORD}@github.com/digitalengineeringtech/fuel-management.git "$ISO_ROOT/custom-configs/backend"

# -------------------------------
# 9. Copy ISO creation script
# -------------------------------
echo "[*] Copying verified-iso-creation.sh to home directory..."
sudo cp "$USER_HOME/the-golden-image/AutoInstall/verified-iso-creation.sh" "$USER_HOME/verified-iso-creation.sh"
sudo chmod +x "$USER_HOME/verified-iso-creation.sh"

echo "[*] Setup complete! Now run the ISO creation script:"
echo "    cd $USER_HOME && sudo ./verified-iso-creation.sh"
echo "[*] Custom ISO will be created at: $OUTPUT_ISO"
