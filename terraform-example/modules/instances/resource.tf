terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.6.7"
    }
  }
}

variable "team" {}
variable "project" {}
variable "subproject" {}
variable "vm_count" {}
variable "project_tags" {}
variable "cores" {}
variable "memory" {}
variable "size" {}
variable "target_node" {}
variable "template_name" {}
variable "region" {}
variable "storage" {}

resource "proxmox_vm_qemu" "vm_creator" {
  ## Wait for the cloud-config file to exist
  count = var.vm_count

  name = "vm-${var.team}-${var.project}-${var.subproject}-${(var.region * 100) + count.index + 1}"

  clone_wait = 60

  desc = var.project_tags
  target_node = var.target_node

  cores = var.cores
  sockets = 1
  # Clone from debian-cloudinit template
  clone = var.template_name

  full_clone = true
  os_type = "cloud-init"

  # Cloud init options
  cicustom = "user=local:snippets/cloud_init_deb10_vm-01.yml"

  memory       = var.memory
  agent        = 1

  # Set the boot disk paramters
  bootdisk = "scsi0"
  scsihw       = "virtio-scsi-pci"

  disk {
    size            = var.size
    type            = "scsi"
    storage         = var.storage
  }

  # Set the network
  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network
    ]
  }
}