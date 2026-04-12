packer {
  required_version = ">= 1.10.0"
  required_plugins {
    hyperv = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/hyperv"
    }
  }
}

# ------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------

variable "iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso"
  description = "URL of the Ubuntu 24.04 LTS server ISO."
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:d6dab0c3a657988501b4bd76dea6af13a7e42f26c59f91c40f3a8b7fa4f2b052"
  description = "Checksum of the ISO. Verify at https://releases.ubuntu.com/24.04.2/SHA256SUMS"
}

variable "vm_name" {
  type    = string
  default = "openclaw-k3s-base"
}

variable "output_directory" {
  type    = string
  default = "output-openclaw-k3s"
}

variable "switch_name" {
  type        = string
  default     = "Default Switch"
  description = "Name of the Hyper-V virtual switch to attach to the VM during build."
}

variable "disk_size_mb" {
  type        = number
  default     = 81920
  description = "Disk size in MB (default: 80 GB)."
}

variable "memory_mb" {
  type        = number
  default     = 8192
  description = "Memory in MB (default: 8 GB)."
}

variable "cpu_count" {
  type    = number
  default = 4
}

variable "ssh_private_key_file" {
  type        = string
  sensitive   = true
  description = "Path to the SSH private key for Packer to connect to the VM after installation. Must match ssh_public_key."
}

# ------------------------------------------------------------------
# Source
# ------------------------------------------------------------------

source "hyperv-iso" "openclaw-k3s" {
  vm_name   = var.vm_name
  generation = 2

  # Secure Boot with Ubuntu-compatible template
  enable_secure_boot   = true
  secure_boot_template = "MicrosoftUEFICertificateAuthority"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  disk_size   = var.disk_size_mb
  memory      = var.memory_mb
  cpus        = var.cpu_count
  switch_name = var.switch_name

  # Hyper-V Enhanced Session requires a different approach; use basic mode
  enable_dynamic_memory = false

  # Serve http/user-data and http/meta-data for NoCloud autoinstall
  http_directory = "${path.root}/http"

  # Ubuntu 24.04 live server GRUB: press 'e' to edit the highlighted entry,
  # navigate to the linux/vmlinuz line and append autoinstall params, then F10 to boot.
  # Adjust wait times if the GRUB screen does not appear in time.
  boot_wait = "10s"
  boot_command = [
    "<wait5>",
    # Edit the first GRUB entry
    "e<wait2>",
    # Move down to the 'linux' kernel line and go to end
    "<down><down><down><end>",
    # Append autoinstall kernel parameters
    " autoinstall 'ds=nocloud;s=http://{{.HTTPIP}}:{{.HTTPPort}}/'",
    "<wait2>",
    # Boot with modified parameters
    "<f10><wait>"
  ]

  communicator         = "ssh"
  ssh_username         = "openclaw"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "45m"

  shutdown_command = "sudo shutdown -P now"
  output_directory = var.output_directory
}

# ------------------------------------------------------------------
# Build
# ------------------------------------------------------------------

build {
  name    = "openclaw-k3s"
  sources = ["source.hyperv-iso.openclaw-k3s"]

  # Wait for cloud-init / subiquity post-install tasks to finish
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to finish...'",
      "sudo cloud-init status --wait --long",
      "echo 'Packer provisioning complete.'"
    ]
  }
}
