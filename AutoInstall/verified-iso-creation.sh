#!/bin/bash

set -e  # Exit on any error

echo "Creating bootable Ubuntu Server ISO..."

# Get the actual user's home directory (even when run with sudo)
if [ -n "$SUDO_USER" ]; then
    USER_HOME="/home/$SUDO_USER"
    ACTUAL_USER="$SUDO_USER"
else
    USER_HOME="$HOME"
    ACTUAL_USER="$(whoami)"
fi

echo "Using home directory: $USER_HOME"
echo "Running as user: $ACTUAL_USER"

# Navigate to the iso-root directory
cd "$USER_HOME/custom-iso/iso-root/"

# Check for required boot files
echo "Checking boot file structure..."

# Check for BIOS boot files
if [ ! -f "boot/grub/i386-pc/eltorito.img" ]; then
    echo "ERROR: BIOS boot image not found: boot/grub/i386-pc/eltorito.img"
    echo "This file should be copied from the original Ubuntu ISO"
    exit 1
fi

# Check for EFI boot files - try common locations
EFI_BOOT_FILE=""
if [ -f "EFI/BOOT/grubx64.efi" ]; then
    EFI_BOOT_FILE="EFI/BOOT/grubx64.efi"
    echo "✓ Found EFI boot file: EFI/BOOT/grubx64.efi"
elif [ -f "EFI/BOOT/bootx64.efi" ]; then
    EFI_BOOT_FILE="EFI/BOOT/bootx64.efi"
    echo "✓ Found EFI boot file: EFI/BOOT/bootx64.efi"
elif [ -f "boot/grub/efi.img" ]; then
    EFI_BOOT_FILE="boot/grub/efi.img"
    echo "✓ Found EFI boot image: boot/grub/efi.img"
else
    echo "ERROR: No EFI boot file found!"
    echo "Expected one of:"
    echo "  - EFI/BOOT/grubx64.efi"
    echo "  - EFI/BOOT/bootx64.efi"
    echo "  - boot/grub/efi.img"
    exit 1
fi

# Check for autoinstall files
if [ ! -f "nocloud/user-data" ]; then
    echo "WARNING: No user-data found in nocloud directory"
fi

if [ ! -f "nocloud/meta-data" ]; then
    echo "Creating meta-data file..."
    echo "instance-id: ubuntu-server-$(date +%s)" > nocloud/meta-data
fi

# Find MBR template
MBR_FILE=""
for mbr in /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/modules/bios/isohdpfx.bin /usr/share/syslinux/isohdpfx.bin; do
    if [ -f "$mbr" ]; then
        MBR_FILE="$mbr"
        echo "✓ Found MBR template: $mbr"
        break
    fi
done

if [ -z "$MBR_FILE" ]; then
    echo "WARNING: MBR template not found. Install syslinux-utils or isolinux"
    echo "sudo apt install syslinux-utils"
    MBR_OPTION=""
else
    MBR_OPTION="-isohybrid-mbr $MBR_FILE"
fi

# Remove old ISO
sudo rm -f ../FMSServerInstaller.iso

# Create the ISO with appropriate options based on found files
echo "Creating ISO..."

# Use sudo for xorriso command
if [ "$EFI_BOOT_FILE" = "boot/grub/efi.img" ]; then
    # Use efi.img method (common in Ubuntu Server ISOs)
    sudo xorriso -as mkisofs \
        -V "FMSServerISO" \
        -o ../FMSServerInstaller.iso \
        -r -J -joliet-long \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot/grub/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        $MBR_OPTION \
        -exclude test-vm.qcow2 \
        -exclude '*.qcow2' \
        -exclude '*.vdi' \
        -exclude '*.vmdk' \
        .
else
    # Use direct EFI file method
    sudo xorriso -as mkisofs \
        -V "FMSServerISO" \
        -o ../FMSServerInstaller.iso \
        -r -J -joliet-long \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot/grub/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e "$EFI_BOOT_FILE" \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        $MBR_OPTION \
        -exclude test-vm.qcow2 \
        -exclude '*.qcow2' \
        -exclude '*.vdi' \
        -exclude '*.vmdk' \
        .
fi

# Fix ownership of the created ISO
sudo chown $ACTUAL_USER:$ACTUAL_USER ../FMSServerInstaller.iso

# Verify the ISO was created
if [ -f "../FMSServerInstaller.iso" ]; then
    ISO_SIZE=$(du -h ../FMSServerInstaller.iso | cut -f1)
    echo ""
    echo "✅ ISO creation completed successfully!"
    echo "📁 File: $USER_HOME/custom-iso/FMSServerInstaller.iso"
    echo "📏 Size: $ISO_SIZE"
    echo ""
    echo "Next steps:"
    echo "1. Copy to USB with Rufus (DD mode recommended)"
    echo "2. Test boot in VM or physical machine"
    echo "3. Check autoinstall logs if issues occur"
else
    echo "❌ ISO creation failed!"
    exit 1
fi