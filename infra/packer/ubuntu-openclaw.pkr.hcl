packer {
  required_plugins {
    vmware = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "vm_name" {
  type    = string
  default = "openclaw-k3s"
}

variable "iso_url" {
  type = string
}

variable "iso_checksum" {
  type = string
}

variable "output_directory" {
  type    = string
  default = "output-openclaw-k3s"
}

variable "headless" {
  type    = bool
  default = false
}

variable "cpus" {
  type    = number
  default = 8
}

variable "memory" {
  type    = number
  default = 32768
}

variable "disk_size_mb" {
  type    = number
  default = 131072
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_private_key_file" {
  type = string
}

source "vmware-iso" "ubuntu" {
  vm_name              = var.vm_name
  guest_os_type        = "ubuntu-64"
  communicator         = "ssh"
  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "45m"
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size_mb
  headless             = var.headless
  output_directory     = var.output_directory
  format               = "vmx"
  http_directory       = "${path.root}/http"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  boot_wait            = "5s"
  shutdown_command     = "sudo shutdown -P now"

  vmx_data = {
    "displayName" = var.vm_name
    "vhv.enable"  = "TRUE"
  }

  boot_command = [
    "<esc><wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]
}

build {
  name    = "ubuntu-openclaw"
  sources = ["source.vmware-iso.ubuntu"]
}
