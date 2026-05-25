# Fetch the proxmox image
resource "libvirt_volume" "os_image" {
  name   = "proxmox-base"
  pool   = "default"
  source = "${var.path_to_image}/proxmox-cloud.qcow2"
  format = "qcow2"
}

# Disco para cada nodo (copy-on-write desde la base)
resource "libvirt_volume" "vm_disk" {
  for_each       = var.nodes
  name           = "${each.key}-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.os_image.id
  format         = "qcow2"
}

resource "null_resource" "resize_volume" {
  for_each = var.nodes

  provisioner "local-exec" {
    command = "sudo qemu-img resize ${libvirt_volume.vm_disk[each.key].id} ${var.diskSize}G"
  }
  depends_on = [libvirt_volume.vm_disk]
}

#--- CUSTOMIZE ISO IMAGE

# 1a. Retrieve our local cloud_init.cfg and update its content
data "template_file" "user_data" {
  for_each = var.nodes

  template = file("${path.module}/config/cloud_init.cfg")
  vars = {
    hostname = each.key
    fqdn     = "${each.key}.${var.domain}"
    ip1      = "${each.value.ip1}"
    ip2      = "${each.value.ip2}"
    gateway  = "${var.gateway}"
  }
}

# 1b. Save the result as user-data
data "template_cloudinit_config" "config" {
  for_each      = var.nodes

  gzip          = false
  base64_encode = false
  part {
    filename     = "user-data"
    content_type = "text/cloud-config"
    content      = "${data.template_file.user_data[each.key].rendered}"
  }
}

# 2. Add network config to the instance
resource "libvirt_cloudinit_disk" "commoninit" {
  for_each   = var.nodes
  name       = "${each.key}-commoninit.iso"
  pool       = "default"
  user_data  = data.template_cloudinit_config.config[each.key].rendered
}

#--- DISCOS ADICIONALES PARA CEPH ---
resource "libvirt_volume" "disk2" {
  for_each = var.nodes
  name     = "${each.key}-disk2"
  pool     = "default"
  format   = "qcow2"
  size     = 1024*1024*1024*50
}

#--- CREATE VM ---
resource "libvirt_domain" "domain-proxmox" {
  for_each = var.nodes
  name     = "${each.key}"
  memory   = var.memoryMB
  vcpu     = var.cpu

  disk {
    volume_id = libvirt_volume.vm_disk[each.key].id
  }

  disk {
    volume_id = libvirt_volume.disk2[each.key].id
  }

  network_interface {
    network_name = "default"
  }

  network_interface {
    network_name = "netstack"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit[each.key].id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # CPU Configuration
  cpu {
    mode = "host-passthrough"  
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = "true"
  }
}
