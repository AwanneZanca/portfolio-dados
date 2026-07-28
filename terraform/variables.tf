variable "project_id" {
  description = "ID do projeto GCP onde a infraestrutura ja existe"
  type        = string
}

variable "region" {
  description = "Regiao GCP"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona GCP da VM"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Nome da instancia que roda Airflow + dbt via Docker Compose"
  type        = string
  default     = "portfolio-dados"
}

variable "machine_type" {
  description = "Tipo de maquina da VM"
  type        = string
  default     = "e2-standard-2"
}

variable "boot_disk_size_gb" {
  description = "Tamanho do disco de boot em GB"
  type        = number
  default     = 20
}

variable "bq_dataset_prefix" {
  description = "Prefixo dos datasets BigQuery da arquitetura Medallion"
  type        = string
  default     = "dados_economicos"
}

variable "bq_location" {
  description = "Localizacao dos datasets BigQuery"
  type        = string
  default     = "us-central1"
}

variable "labels" {
  description = "Labels aplicadas aos recursos, para rastreabilidade de custo"
  type        = map(string)
  default = {
    projeto    = "pipeline-dados-gcp-bacen"
    gerido_por = "terraform"
  }
}
