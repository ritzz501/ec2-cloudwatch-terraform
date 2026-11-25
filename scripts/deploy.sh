#!/usr/bin/env bash
set -euo pipefail
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
rm -f tfplan
printf '\nDeployment complete. Save the instance ID, public IP and alarm name shown above.\n'
