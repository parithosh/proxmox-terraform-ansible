terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.6.7"
    }
  }
}


variable "project_tags_default" {
  type = object({
    Project     = string
    SubProject  = string
    Environment = string
    Team        = string
    Creator     = string
    Created_by  = string
  })
  default = {
    Team        = "example"
    Project     = "example"
    SubProject  = "example"
    Environment = "proxmox"
    Creator     = "example"
    Created_by  = "Terraform"
  }
}


variable pm_user {}
variable pm_password {}
variable pm_api_url {}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  pm_user = var.pm_user
  pm_password = var.pm_password
  pm_tls_insecure = true
  pm_timeout = 10000
}

# Source the Cloud Init Config file
data "template_file" "cloud_init_deb10_vm-01" {
  template  = file("${path.module}/files/cloud_init_deb10.cloud_config")

  vars = {
    ssh_key = file("~/.ssh/id_ed25519.pub") # path to local ssh key
    hostname = "vm-01"
    domain = "example-01.proxmox"
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_deb10_vm-01" {
  content   = data.template_file.cloud_init_deb10_vm-01.rendered
  filename  = "${path.module}/files/user_data_cloud_init_deb10_vm-01.cfg"
}

# Transfer the file to the Proxmox Host, Need to do this one time per node
resource "null_resource" "cloud_init_<TARGET-NODE-NAME>" {
  connection {
    type    = "ssh"
    user    = "devops"
    host    = "<IP-ADDRESS>"
  }

  provisioner "file" {
    source       = local_file.cloud_init_deb10_vm-01.filename
    destination  = "/home/devops/cloud_init_deb10_vm-01.yml"
  }
  # Needed this since root access is needed to move a file into /var/lib/vz, but root ssh is disabled
  provisioner "remote-exec" {
    inline = [
      "sudo cp /home/devops/cloud_init_deb10_vm-01.yml /var/lib/vz/snippets/cloud_init_deb10_vm-01.yml",
    ]
  }
}


# One module per proxmox host/region
module "region-1" {
  depends_on = [
    null_resource.cloud_init_<TARGET-NODE-NAME>
  ]

  source = "../../modules/instances"

  team = var.project_tags_default.Team
  project = var.project_tags_default.Project
  subproject = var.project_tags_default.SubProject

  vm_count = 0

  cores  = 4
  memory = 8000
  size   = "30G"
  storage = "local"
  target_node = "<TARGET-NODE-NAME>"
  template_name = "debian-cloudinit-<TARGET-NODE-NAME>"
  project_tags = jsonencode(var.project_tags_default)
  region = 1
}

