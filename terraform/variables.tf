variable "hostname" {
  default = "proxnode"
  description = "Proxmox en cloud"
}

variable "domain" {
  default = "midominio.org"
}

variable "memoryMB" {
  default = 8192  # 8GB por nodo
}

variable "cpu" {
  default = 4
}

variable "diskSize" {
  default = 32
}

variable "path_to_image" {
  default = "/home/vicenterog/vmstore"
}

variable "nodes" {
  default = {
    proxnode1 = {
      ip1 = "192.168.122.11"
      ip2 = "172.24.4.11"
    },
    proxnode2 = {
      ip1 = "192.168.122.12"
      ip2 = "172.24.4.12"
    },
    proxnode3 = {
      ip1 = "192.168.122.13"
      ip2 = "172.24.4.13"
    }
  }
}

variable "gateway" {
  default = "192.168.122.1"
}
