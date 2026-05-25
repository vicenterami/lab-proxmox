# Proxmox VE Lab — Clúster de Alta Disponibilidad (HA) con Ceph

Laboratorio para desplegar un clúster de virtualización de 3 nodos Proxmox en Alta Disponibilidad, utilizando almacenamiento distribuido Ceph. Todo aprovisionado sobre KVM usando Terraform y configurado con Ansible.

## Arquitectura de Virtualización Anidada

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                          Host Físico (Ubuntu / KVM)                     │
│                                                                         │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │
│  │    proxnode1   │  │    proxnode2   │  │    proxnode3   │             │
│  │ .11 (Proxmox)  │  │ .12 (Proxmox)  │  │ .13 (Proxmox)  │             │
│  │                │  │                │  │                │             │
│  │  ┌──────────┐  │  │  ┌──────────┐  │  │  ┌──────────┐  │             │
│  │  │ VM Alpine│<─┼──┼─>│ (Migra en│  │  │  │ (Migra en│  │  <-- HA     │
│  │  │ (Activa) │  │  │  │ caso de  │  │  │  │ caso de  │  │             │
│  │  └──────────┘  │  │  │  fallo)  │  │  │  │  fallo)  │  │             │
│  │                │  │  └──────────┘  │  │  └──────────┘  │             │
│  │   Ceph OSD 1   │  │   Ceph OSD 2   │  │   Ceph OSD 3   │  <-- Storage│
│  └────────────────┘  └────────────────┘  └────────────────┘             │
│            192.168.122.0/24 (Red de Gestión y Sincronización)           │
└─────────────────────────────────────────────────────────────────────────┘
```

| Nodo        | IP                | Rol en el Clúster           | Almacenamiento      |
|-------------|-------------------|-----------------------------|---------------------|
| proxnode1   | 192.168.122.11    | Master/Worker + Ceph MON/MGR| OSD 1 (Disco block) |
| proxnode2   | 192.168.122.12    | Master/Worker + Ceph MON/MGR| OSD 2 (Disco block) |
| proxnode3   | 192.168.122.13    | Master/Worker + Ceph MON/MGR| OSD 3 (Disco block) |

## Requisitos

- CPU con soporte para Virtualización Anidada (AMD-V / VT-x activado).
- KVM / libvirt instalado (`qemu:///system`).
- Terraform >= 1.0 & Ansible >= 2.12.
- Imagen Cloud de Proxmox.

## Estructura del repositorio

```text
lab-proxmox/
├── terraform/
│   ├── main.tf               # Aprovisionamiento de VMs Proxmox base (Nested KVM)
│   ├── variables.tf
│   ├── terraform.tf
│   └── config/
│       └── cloud_init.cfg    # Pre-configuración de red y usuarios para Proxmox
├── ansible/
│   ├── inventory.ini         # Inventario de los 3 proxnodes
│   ├── 01_setup_cluster.yml  # Configura locales, SSH y une los nodos al clúster Proxmox
│   ├── 02_setup_ceph.yml     # Instala y configura Ceph (MON, MGR, OSD, Pools)
│   ├── 03_setup_sdn.yml      # Configura redes definidas por software (SDN)
│   └── 04_deploy_vm.yml      # Despliega VM Alpine Linux de prueba
└── README.md
```

## Flujo de Trabajo y Pruebas

1. **Aprovisionamiento:** Terraform crea 3 VMs y les inyecta la imagen de Proxmox usando Cloud-Init.
2. **Configuración Base:** Ansible configura la confianza SSH sin contraseña entre los nodos.
3. **Clúster y Storage:** Ansible une los nodos y configura Ceph para que compartan el almacenamiento.
4. **Prueba HA (Alta Disponibilidad):**
   - Se crea una VM (Alpine Linux) en `proxnode1`.
   - Se incluye la VM en un "Grupo HA" de Proxmox.
   - **Simulación de Caída:** Se apaga abruptamente `proxnode1`.
   - **Comportamiento Esperado:** El clúster detecta el fallo (pérdida de quórum del nodo 1) y reinicia automáticamente la VM de Alpine en `proxnode2` o `proxnode3` sin intervención manual.