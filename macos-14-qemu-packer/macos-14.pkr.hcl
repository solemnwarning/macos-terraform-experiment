packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "base_dir" {
  type    = string
  default = "base/"
}

variable "output_dir" {
  type    = string
  default = "output/"
}

variable "uefi_firmware" {
  type    = string
  default = "/usr/share/OVMF/OVMF_CODE.fd"
}

variable "yq_binary_url" {
  type    = string
  default = "https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_darwin_amd64"
}

build {
  sources = ["source.qemu.macos"]

  # We need to explicitly enable TRIM support since we aren't using official Apple-approved disks.

  provisioner "shell" {
    inline = [
      "yes | sudo trimforce enable",
    ]

    expect_disconnect = true
    pause_after = "2m"
  }

  # Download and install pre-compiled yq executable.

  provisioner "shell-local" {
    inline = [
      "test -e yq || wget -O yq ${var.yq_binary_url}",
    ]
  }

  provisioner "file" {
    source = "yq"
    destination = "/tmp/"
    generated = true
  }

  provisioner "shell" {
    inline = [
      "sudo install -d /usr/local/bin/",
      "sudo install -m 0755 /tmp/yq /usr/local/bin/",
    ]
  }

  # Install macos-init.

  provisioner "file" {
    sources = [
      "../macos-init",
      "macos-init.conf",
    ]

    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "cd /tmp/macos-init/",
      "sudo ./install.sh",

      "sudo install -m 0644 /tmp/macos-init.conf /usr/local/etc/macos-init.conf",
    ]
  }

  # Copy other files from base directory to output and generate checksums.

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cp ${var.base_dir}/OpenCore.qcow2 ${var.output_dir}/",
      "cp ${var.base_dir}/OVMF_VARS.fd ${var.output_dir}/",

      "cd ${var.output_dir}/",
      "sha256sum macos.qcow2 OpenCore.qcow2 OVMF_VARS.fd > SHA256SUMS",
    ]
  }
}

source qemu "macos" {
  iso_url          = "${var.base_dir}/macos.qcow2"
  iso_checksum     = "none"
  disk_image       = true
  skip_resize_disk = true

  # Create a full copy of the base image
  use_backing_file = false

  machine_type = "q35"

  cpus        = 4
  memory      = 4096
  accelerator = "kvm"

  efi_boot         = true
  efi_drop_efivars = false

  qemuargs = [
    [ "-device", "isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" ],
    [ "-smbios", "type=2" ],

    [ "-cpu", "Haswell-noTSX,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check" ],

    [ "-device", "ahci,id=ahci" ],

    [ "-drive", "if=none,id=disk0,format=qcow2,file=${var.base_dir}/OpenCore.qcow2" ],
    [ "-device", "ide-hd,drive=disk0,bus=ahci.0,rotation_rate=1" ],

    [ "-drive", "if=none,id=disk1,format=qcow2,file=${var.output_dir}/macos.qcow2,cache=unsafe,discard=unmap,detect-zeroes=unmap" ],
    [ "-device", "ide-hd,drive=disk1,bus=ahci.1,rotation_rate=1" ],

    [ "-drive", "if=pflash,format=raw,readonly=true,file=${var.uefi_firmware}" ],
    [ "-drive", "if=pflash,format=raw,readonly=true,file=${var.base_dir}/OVMF_VARS.fd" ],
  ]

  # Comment this line to enable the local QEMU display.
  headless = true

  # Uncomment this line to enable remove VNC access to the display.
  # vnc_bind_address = "0.0.0.0"

  communicator = "ssh"
  ssh_username = "packer"
  ssh_password = "packer"

  shutdown_command = "sudo shutdown -h now"
  shutdown_timeout = "30m"

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  format           = "qcow2"
  output_directory = "${var.output_dir}"
  vm_name          = "macos.qcow2"
}
