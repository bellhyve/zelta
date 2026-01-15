```
#!/bin/sh

set -x

# 1. Check if your CPU supports virtualization
# If this returns > 0, you're good
if egrep -c '(vmx|svm)' /proc/cpuinfo; then
   echo "CPU supports virtualizaton, install KVM/QEMU and virt-manager"
else
   echo "your cpu does not support virualization, cannot install KVM!"
   return 1
fi


# 2. Install KVM and tools
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# 3. Add your user to libvirt groups
sudo usermod -aG libvirt dever
sudo usermod -aG kvm dever

# 4. Start the libvirt service
sudo systemctl enable --now libvirtd

# 5. Verify installation
sudo virsh list --all

# 6. Log out and back in (for group membership to take effect)

set +x
```


```
#!/bin/sh

set -x
sudo apt install -y virt-viewer libvirt-daemon-system libvirt-clients qemu-kvm
sudo systemctl enable --now libvirtd
sudo systemctl status libvirtd

sudo usermod -aG libvirt,kvm $USER
id $USER
virsh -c qemu:///system list
virt-viewer --connect qemu:///system zfs-dev

set +x


# ToDo
echo "on the VM run:"
echo "sudo systemctl enable --now serial-getty@ttyS0.service"
```
