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

variable "network_adapter_type" {
  type    = string
  default = "vmxnet3"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_private_key_file" {
  type = string
}

variable "enable_nested_virtualization" {
  type    = bool
  default = false
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
  network_adapter_type = var.network_adapter_type
  headless             = var.headless
  output_directory     = var.output_directory
  format               = "vmx"
  http_directory       = "${path.root}/http"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  boot_wait            = "5s"
  boot_key_interval    = "50ms"
  boot_keygroup_interval = "500ms"
  shutdown_command     = "sudo shutdown -P now"

  # Attach user-data and meta-data as a cidata ISO so the installer detects
  # autoinstall automatically without needing kernel command-line manipulation.
  cd_files = [
    "${path.root}/http/user-data",
    "${path.root}/http/meta-data",
  ]
  cd_label = "cidata"

  vmx_data = {
    "displayName" = var.vm_name
    "vhv.enable"  = var.enable_nested_virtualization ? "TRUE" : "FALSE"
  }

  # Boot default GRUB entry; cidata ISO provides autoinstall config.
  # Without 'autoinstall' on the kernel command line, subiquity asks for
  # confirmation once — answer automatically after the installer has started.
  boot_command = [
    "<enter>",
    "<wait90>",
    "yes<enter>"
  ]
}

build {
  name    = "ubuntu-openclaw"
  sources = ["source.vmware-iso.ubuntu"]
}
