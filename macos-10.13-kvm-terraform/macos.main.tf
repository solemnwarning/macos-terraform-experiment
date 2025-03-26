terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  # Connect to libvirtd running locally.
  uri = "qemu:///system"

  # Remote libvirt hosts can be used with a uri like this:
  # uri = "qemu+ssh://username@your-remote-kvm-host/system?sshauth=privkey"
}

resource "libvirt_volume" "disk" {
  name   = "${ var.hostname }.${ var.domain }.qcow2"
  source = "../macos-10.13-qemu-packer/output/macos.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "opencore" {
  name   = "${ var.hostname }.${ var.domain }.OpenCore.qcow2"
  source = "../macos-10.13-qemu-packer/output/OpenCore.qcow2"
  format = "qcow2"
}

# Upload the UEFI variables file as a raw disk image file.
resource "libvirt_volume" "efi_vars" {
  name   = "${ var.hostname }.${ var.domain }.VARS.fd"
  source = "../macos-10.13-qemu-packer/output/OVMF_VARS.fd"
  format = "raw"
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  name = "${ var.hostname }.${ var.domain }.cloud-init.iso"

  user_data  = templatefile("macos.user-data.tftpl", {
    hostname = "${ var.hostname }"
    domain   = "${ var.domain }"
  })
}

resource "libvirt_domain" "macos" {
  name    = "${ var.hostname }.${ var.domain }"
  memory  = 4096
  vcpu    = 4
  running = false

  # macOS needs very specific configuration which isn't supported by the
  # libvirt Terraform provider, but it does allow us to transform the generated
  # domain XML using XSLT (see macos.domain.xsl for more details).
  xml {
    xslt = file("macos.domain.xsl")
  }

  firmware = "/usr/share/OVMF/OVMF_CODE.fd"
  nvram {
    file = "${libvirt_volume.efi_vars.id}"
  }

  network_interface {
    # Put your bridge interface name here, or use a different type of network
    # interface (see the documentation for the libvirt Terraform provider) for
    # more information.
    bridge = "br0"
  }

  disk {
    volume_id = "${libvirt_volume.opencore.id}"
  }

  disk {
    volume_id = "${libvirt_volume.disk.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.cloud_init.id}"
}
