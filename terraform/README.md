# Infraestrutura (Terraform)

Rastreia como código a infraestrutura GCP que já existe e roda em produção — não cria
do zero. Os 10 recursos abaixo foram trazidos para o Terraform via `terraform import`,
preservando exatamente o que já estava provisionado manualmente:

- VM `portfolio-dados` (`e2-standard-2`, Ubuntu 22.04 LTS) onde roda o Airflow + dbt via
  Docker Compose.
- IP externo estático `airflow-ip`.
- Firewalls existentes `allow-airflow` (porta 8080) e `allow-jenkins` (porta 8081).
- Service Account `airflow-bigquery` (usada via chave JSON montada no container do
  Airflow, ver `docker-compose.yaml`) com os papéis `bigquery.dataEditor` e
  `bigquery.studioUser`.
- Os 3 datasets BigQuery da arquitetura Medallion (`*_bronze`, `*_silver`, `*_gold`),
  em `us-central1`.

A VM tem `lifecycle.ignore_changes = all` — o Terraform rastreia o recurso mas nunca
tenta alterá-lo, evitando risco de recriar uma instância real por causa de atributos
computados pela API (shielded VM, scheduling, metadata de SSH) que este código não
modela.

## Uso

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars com seu project_id

terraform init
terraform plan   # deve mostrar "No changes" se nada mudou na infra real
```

**Nunca commite `terraform.tfvars` nem `*.tfstate`** — já estão no `.gitignore` local
desta pasta. Em uso real, o `.tfstate` deveria ficar num backend remoto (ex: bucket GCS),
não local — isso não está configurado aqui de propósito, para manter o exemplo simples de
rodar.

## Se for recriar essa infra em outro projeto GCP do zero

Remova o `lifecycle.ignore_changes` da VM e rode `terraform apply` normalmente — sem
recursos existentes para importar, ele cria tudo novo.

## O que NÃO está aqui

Este Terraform não recria o cluster do Airflow em si (isso continua via `docker-compose.yaml`
rodando dentro da VM) nem o job do Jenkins — ele só garante que a VM, a rede e os datasets
existem antes de tudo isso subir.
