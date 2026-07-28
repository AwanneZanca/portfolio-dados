# -----------------------------------------------------------------------------
# Service Account existente, usada por dentro do container do Airflow (via
# gcp_credentials.json montado, ver docker-compose.yaml) para acessar o
# BigQuery. Nao esta anexada a VM em si -- a VM usa a service account padrao
# do Compute Engine (ver abaixo).
# -----------------------------------------------------------------------------
resource "google_service_account" "airflow_bigquery" {
  account_id   = "airflow-bigquery"
  display_name = "airflow-bigquery"
}

resource "google_project_iam_member" "airflow_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.airflow_bigquery.email}"
}

resource "google_project_iam_member" "airflow_bigquery_studio_user" {
  project = var.project_id
  role    = "roles/bigquery.studioUser"
  member  = "serviceAccount:${google_service_account.airflow_bigquery.email}"
}

# Service account padrao do Compute Engine -- e a que a VM realmente usa
data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# -----------------------------------------------------------------------------
# Rede: IP externo estatico existente + firewall rules existentes (Airflow UI
# na 8080, Jenkins na 8081). SSH ja e coberto pela regra default-allow-ssh do
# GCP, entao nao criamos uma regra nova para isso.
# -----------------------------------------------------------------------------
resource "google_compute_address" "airflow_static_ip" {
  name   = "airflow-ip"
  region = var.region
}

resource "google_compute_firewall" "allow_airflow" {
  name        = "allow-airflow"
  network     = "default"
  description = "Acesso ao Airflow porta 8080"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_jenkins" {
  name    = "allow-jenkins"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8081"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# VM: Ubuntu 22.04 LTS, e2-standard-2, com Docker + Docker Compose instalados
# via startup script.
# -----------------------------------------------------------------------------
resource "google_compute_instance" "airflow_vm" {
  project      = var.project_id
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.airflow_static_ip.address
    }
  }

  service_account {
    email = data.google_compute_default_service_account.default.email
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    usermod -aG docker $(logname) || true
  EOT

  # A VM ja existe e roda em producao (parada no momento). So queremos
  # rastrea-la no Terraform, nao arriscar recriar/alterar algo que ja
  # funciona por causa de atributos computados pela API (shielded VM,
  # scheduling, metadata de SSH, etc) que nao estamos modelando aqui.
  lifecycle {
    ignore_changes = all
  }
}

# -----------------------------------------------------------------------------
# BigQuery: os 3 datasets existentes da arquitetura Medallion
# -----------------------------------------------------------------------------
resource "google_bigquery_dataset" "bronze" {
  project     = var.project_id
  dataset_id  = "${var.bq_dataset_prefix}_bronze"
  location    = var.bq_location
  description = "Camada Bronze: dados brutos ingeridos pelo Airflow (BACEN diario, IBGE semanal)"
  labels      = var.labels
}

resource "google_bigquery_dataset" "silver" {
  project     = var.project_id
  dataset_id  = "${var.bq_dataset_prefix}_silver"
  location    = var.bq_location
  description = "Camada Silver: views tratadas/padronizadas geradas pelo dbt (stg_bacen, stg_ibge)"
  labels      = var.labels
}

resource "google_bigquery_dataset" "gold" {
  project     = var.project_id
  dataset_id  = "${var.bq_dataset_prefix}_gold"
  location    = var.bq_location
  description = "Camada Gold: Star Schema (dim_tempo, dim_indicador, fato_indicadores) consumido pelo Looker Studio"
  labels      = var.labels
}
