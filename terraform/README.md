# Infraestrutura (Terraform)

Provisiona, de forma declarativa, a infraestrutura GCP que hoje o [README raiz](../README.md)
descreve como criada manualmente:

- VM `e2-medium` (Ubuntu 22.04 LTS) onde roda o Airflow + dbt via Docker Compose, com
  Docker instalado automaticamente no boot (`metadata_startup_script`).
- IP externo estático.
- Firewall liberando apenas SSH (22) e a UI do Airflow (8080), restrito às faixas de IP
  definidas em `ssh_source_ranges`.
- Service Account dedicada para a VM acessar o BigQuery (substitui o `gcp_credentials.json`
  montado manualmente hoje).
- Os 3 datasets BigQuery da arquitetura Medallion (`*_bronze`, `*_silver`, `*_gold`).

## Uso

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars com seu project_id e (recomendado) restrinja ssh_source_ranges

terraform init
terraform plan
terraform apply
```

**Nunca commite `terraform.tfvars` nem `*.tfstate`** — já estão no `.gitignore` local
desta pasta. Em uso real, o `.tfstate` deveria ficar num backend remoto (ex: bucket GCS),
não local — isso não está configurado aqui de propósito, para manter o exemplo simples de
rodar.

## O que NÃO está aqui

Este Terraform não recria o cluster do Airflow em si (isso continua via `docker-compose.yaml`
rodando dentro da VM) nem o job do Jenkins — ele só garante que a VM, a rede e os datasets
existem antes de tudo isso subir.
