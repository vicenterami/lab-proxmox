#!/bin/bash
# Script para resetear fingerprints SSH de los nodos Proxmox

NODES=("192.168.122.11" "192.168.122.12" "192.168.122.13")

for NODE in "${NODES[@]}"; do
    echo "🔄 Limpiando fingerprint de $NODE..."
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$NODE"
done

echo "✅ Fingerprints eliminados. Ahora reconecta con: ssh root@<IP>"
