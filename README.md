# macos-terraform-experiment

## Introduction

This repository has my (experimental) attempts at building x64 macOS guests using Packer/QEMU and deploying them to libvirt KVM hosts using Terraform.

This is mostly built on top of the work of other people, all I've done is bring the parts together.

## Usage

### Preparing the "base" image

I haven't found any way of performing an "unattended" installation of any modern versions of macOS (nice work, Apple!), so my Packer scripts unfortunately require a manually-prepared base image, which can be further updated/customised/etc using Packer later.

The steps to prepare a base image as as follows:

1. Install macOS under KVM using the code/instructions at [OSX-KVM](https://github.com/kholia/OSX-KVM).
2. Create an Administrator account with username and password of "packer"
3. Enable password-less sudo for the packer account.
4. Ensure automatic suspend/sleep is disabled.
5. Enable SSH access.
6. Ensure the macOS drive is the default startup drive.
7. Reduce the OpenCore boot timeout (optional).

Once you've done the above, copy the macOS hard disk image, OpenCore disk image and UEFI variables into the appropriate `base` directory, you should have a file tree something like this:

- `macos-10.13-qemu-packer/base/macos.qcow2`
- `macos-10.13-qemu-packer/base/OpenCore.qcow2`
- `macos-10.13-qemu-packer/base/OVMF_VARS.fd`

### Customising the base image with Packer

Once the base image has been prepared, you can create new images with further customisations using Packer, which is a widely-used tool so I won't go into great detail. The included example Packer scripts install `macos-init` (a macOS equivalent to `cloud-init` and not a lot else).

Example usage:

```
$ cd macos-10.13-qemu-packer/
$ packer init macos-10.13.pkr.hcl
$ packer build macos-10.13.pkr.hcl
```

### Deploying the customised image using Terraform

Now you have a (barely) customised macOS image, you can use Terraform to deploy it to a libvirt KVM host and make minor configuration changes. The included Terraform examples simply change the hostname via `macos-init` which we installed as part of the image customisation.

Example usage:

```
$ cd macos-10.13-kvm-terraform/
$ terraform init
$ terraform apply
```
