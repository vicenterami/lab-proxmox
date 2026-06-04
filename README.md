# Proxmox VE Lab — Clúster HA con Ceph y SDN

Laboratorio para desplegar un clúster de 3 nodos Proxmox en Alta
Disponibilidad con almacenamiento distribuido Ceph y redes SDN.
Aprovisionado sobre KVM con Terraform y configurado con Ansible.

## Arquitectura

```
┌──────────────────────────────────────────────────────┐
│                Host Físico (Ubuntu/KVM)              │
│                                                      │
│  proxnode1(.11)   proxnode2(.12)   proxnode3(.13)     │
│  ┌──────────┐     ┌──────────┐     ┌──────────┐      │
│  │VM Alpine │────>│(failover)│     │(failover)│  HA  │
│  │172.24.4.10     └──────────┘     └──────────┘      │
│  │Ceph OSD1 │     Ceph OSD2        Ceph OSD3         │
│  │MON+MGR   │     MON+MGR          MON+MGR           │
│  └──────────┘                                        │
│       192.168.122.0/24  ── gestión y Ceph            │
│       172.24.4.0/24     ── SDN/VMs (NAT→internet)    │
└──────────────────────────────────────────────────────┘
```

| Nodo      | IP             | Roles                         |
|-----------|----------------|-------------------------------|
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
│   ├── main.tf              # VMs KVM con virtualización anidada
│   ├── variables.tf
│   └── config/
│       └── cloud_init.cfg   # Red y usuarios iniciales de Proxmox
└── ansible/
    ├── ansible.cfg
    ├── inventory.yml        # Los 3 proxnodes
    ├── deploy_lab.yml       # Stages 1-8: cluster+Ceph+SDN+routing+NAT
    ├── create_alpine_vm.yml # VM Alpine Linux con cloud-init en Ceph
    ├── setup_ha.yml         # Alta Disponibilidad
    ├── fix_routing.yml      # ip_forward + NAT + rutas SDN (idempotente)
    └── locale_es.yml        # Locales opcionales
```

## Despliegue completo desde cero

```bash
# 1. Aprovisionar VMs KVM con Terraform
cd terraform
terraform init
terraform apply --auto-approve

# 2. Limpiar fingerprints SSH
./reset_ssh_finger.sh

# 3. Desplegar clúster (Proxmox + Ceph + SDN + NAT)
cd ansible
ansible-playbook deploy_lab.yml

# 4. Crear VM Alpine de prueba
ansible-playbook create_alpine_vm.yml

# 5. Configurar Alta Disponibilidad
ansible-playbook setup_ha.yml
```

## Prueba de Alta Disponibilidad

```bash
# Terminal 1 — monitorear el clúster
watch -n2 'ssh root@192.168.122.12 "ha-manager status" 2>/dev/null'

# Terminal 2 — simular fallo del nodo master
ssh root@192.168.122.11 "shutdown -h now"

# Resultado esperado en ~60s:
# service vm:9001 (proxnode2, started)  ← migró automáticamente
```

## Acceso SSH a las VMs

Agrega esto a `~/.ssh/config`:

```
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
```

```bash
# Conectar directamente a la VM Alpine
ssh root@172.24.4.10
```