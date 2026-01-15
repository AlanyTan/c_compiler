packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "archlinux" {
  boot_command = [
    "<enter><wait10>",
    "dhcpcd<enter><wait10>",
    "usermod --password $(echo toor | openssl passwd -1 -stdin) root<enter><wait10>",
    "systemctl start sshd<enter>"
  ]
  boot_wait        = "10s"
  disk_size        = "2048M"
  disk_interface   = "ide"
  format           = "raw"
  headless         = true
  iso_url          = "../../images/archlinux.iso"
  iso_checksum     = "none"
  qemu_binary      = "/usr/bin/qemu-system-i386"
  machine_type     = "pc"
  shutdown_command = "shutdown -P now"
  ssh_password     = "toor"
  ssh_port         = 22
  ssh_username     = "root"
  ssh_wait_timeout = "120s"
  vm_name          = "Archlinux-v86"
  accelerator      = "none"
}

build {
  sources = ["source.qemu.archlinux"]

  provisioner "shell" {
    scripts = ["scripts/provision.sh"]
  }
}
