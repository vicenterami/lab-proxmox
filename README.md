# Proxmox VE Lab — Clúster HA con Ceph y SDN

Laboratorio para desplegar un clúster de 3 nodos Proxmox en Alta
Disponibilidad con almacenamiento distribuido Ceph y redes SDN.
Aprovisionado sobre KVM con Terraform y configurado con Ansible.

## Arquitectura

```text
┌─────────────────────────────────────────────────┐
│              Host Físico (Ubuntu/KVM)           │
│                                                 │
│  proxnode1 (.11)  proxnode2 (.12)  proxnode3 (.13)│
│  ┌───────────┐   ┌───────────┐   ┌───────────┐  │
│  │ VM Alpine │──>│ (failover)│   │ (failover)│  │
│  │ 172.24.4.10│  └───────────┘   └───────────┘  │
│  │ Ceph OSD1 │   Ceph OSD2       Ceph OSD3      │
│  └───────────┘                                  │
│          192.168.122.0/24 (gestión)             │
│          172.24.4.0/24   (SDN/VMs)              │
└─────────────────────────────────────────────────┘
```

| Nodo      | IP             | Roles                        |
|-----------|----------------|------------------------------|
| proxnode1 | 192.168.122.11 | Master inicial, MON, MGR, OSD |
| proxnode2 | 192.168.122.12 | Worker, MON, MGR, OSD         |
| proxnode3 | 192.168.122.13 | Worker, MON, MGR, OSD         |

## Requisitos

- CPU con virtualización anidada (AMD-V / Intel VT-x)
- KVM/libvirt instalado
- Terraform >= 1.0
- Ansible >= 2.12

## Estructura

```
lab-proxmox/
├── terraform/
│   ├── main.tf            # VMs KVM (nested virtualization)
│   ├── variables.tf
│   └── config/
│       └── cloud_init.cfg # Red y usuarios iniciales
└── ansible/
    ├── ansible.cfg
    ├── inventory.yml      # Los 3 proxnodes
    ├── deploy_lab.yml     # Stages 1-8: cluster+Ceph+SDN+routing
    ├── create_alpine_vm.yml # VM Alpine Linux con cloud-init
    ├── setup_ha.yml       # Alta Disponibilidad
    ├── fix_routing.yml    # ip_forward + NAT + rutas SDN
    └── locale_es.yml      # Locales opcionales
```

## Despliegue

```bash
# 1. Aprovisionar VMs con Terraform
cd terraform && terraform apply

# 2. Desplegar clúster completo
cd ansible
ansible-playbook deploy_lab.yml

# 3. Crear VM de prueba
ansible-playbook create_alpine_vm.yml

# 4. Configurar HA
ansible-playbook setup_ha.yml
```

## Prueba de Alta Disponibilidad

```bash
# Terminal 1 — monitorear
watch -n2 'ssh root@192.168.122.12 "ha-manager status"'

# Terminal 2 — simular fallo
ssh root@192.168.122.11 "shutdown -h now"

# Resultado esperado: VM migra a proxnode2 o proxnode3 en ~60s
```

## Acceso a las VMs

```bash
# Configurar ~/.ssh/config (ejecutar una vez)
Host proxnode1
    HostName 192.168.122.11
    User root
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host 172.24.4.*
    User root
    IdentityFile ~/github-repositorios/lab-proxmox/ansible/rootkey
    ProxyJump proxnode1
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Conectar a la VM Alpine
ssh root@172.24.4.10
```