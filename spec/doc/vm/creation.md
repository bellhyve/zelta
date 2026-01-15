# VM Creation Guide


## setting up an Ubuntu VM on Ubuntu

```shell
#!/bin/sh
# Download Ubuntu ISO
#wget https://releases.ubuntu.com/noble/ubuntu-24.04.3-desktop-amd64.iso

set -x

UBUNTU_ISO_SRC_DIR="/home/dever/Downloads"
UBUNTU_ISO_VIRT_DIR="/var/lib/libvirt/boot"
UBUNTU_ISO_NAME="ubuntu-24.04.3-live-server-amd64.iso"

UBUNTU_SRC_ISO="$UBUNTU_ISO_SRC_DIR/$UBUNTU_ISO_NAME"
UBUNTU_TGT_ISO="$UBUNTU_ISO_VIRT_DIR/$UBUNTU_ISO_NAME"

sudo mkdir -p "${UBUNTU_ISO_VIRT_DIR}"
sudo cp -f "${UBUNTU_SRC_ISO}" "$UBUNTU_TGT_ISO" 

# Optional: lock down permissions
sudo chmod 644 "$UBUNTU_TGT_ISO" 
sudo chown root:root "$UBUNTU_TGT_ISO" 


sudo virt-install \
  --name zfs-dev \
  --ram 8192 \
  --disk path=/var/lib/libvirt/images/zfs-dev.qcow2,size=40,format=qcow2 \
  --vcpus 4 \
  --os-variant ubuntu24.04 \
  --network bridge=virbr0 \
  --graphics spice \
  --cdrom "${UBUNTU_TGT_ISO}"


set +x

```
