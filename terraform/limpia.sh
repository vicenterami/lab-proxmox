#!/bin/bash

echo "1. Destruyendo las máquinas de Terraform..."
terraform destroy -auto-approve

echo "2. Borrando archivos temporales y estados de Terraform..."
rm -rf .terraform*
rm -f terraform.tfstate*


echo "¡Limpieza total terminada!"