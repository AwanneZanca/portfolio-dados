variable "project_id" {
  description = "ID do projeto GCP onde a infraestrutura sera criada"
  type        = string
}

variable "region" {
  description = "Regiao GCP"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona GCP para a VM"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Nome da instancia que roda Airflow + dbt via Docker Compose"
  type        = string
  default     = "airflow-bacen-vm"
}

variable "machine_type" {
  description = "Tipo de maquina da VM (2 vCPU, 4GB RAM conforme documentado no README)"
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size_gb" {
  description = "Tamanho do disco de boot em GB"
  type        = number
  default     = 30
}

variable "ssh_source_ranges" {
  description = "Faixas de IP autorizadas a acessar SSH (22) e a UI do Airflow (8080). Restrinja ao seu IP em producao."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bq_dataset_prefix" {
  description = "Prefixo dos datasets BigQuery da arquitetura Medallion"
  type        = string
  default     = "dados_economicos"
}

variable "bq_location" {
  description = "Localizacao dos datasets BigQuery"
  type        = string
  default     = "US"
}

variable "labels" {
  description = "Labels aplicadas aos recursos, para rastreabilidade de custo"
  type        = map(string)
  default = {
    projeto    = "pipeline-dados-gcp-bacen"
    gerido_por = "terraform"
  }
}
