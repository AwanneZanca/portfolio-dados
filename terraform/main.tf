# -----------------------------------------------------------------------------
# Service Account usada pela VM para gravar/ler no BigQuery (substitui o
# gcp_credentials.json montado manualmente hoje em /home/.../gcp_credentials.json)
# -----------------------------------------------------------------------------
resource "google_service_account" "airflow_vm" {
  account_id   = "airflow-bacen-sa"
  display_name = "Service Account da VM do Airflow (pipeline BACEN/IBGE)"
}

resource "google_project_iam_member" "airflow_vm_bq_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.airflow_vm.email}"
}

resource "google_project_iam_member" "airflow_vm_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.airflow_vm.email}"
}

# -----------------------------------------------------------------------------
# Rede: IP externo estatico (o README menciona "IP estatico, nao muda ao
# reiniciar") + firewall liberando so o necessario (SSH e a UI do Airflow)
# -----------------------------------------------------------------------------
resource "google_compute_address" "airflow_vm_static_ip" {
  name   = "${var.vm_name}-ip"
  region = var.region
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-${var.vm_name}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["airflow-bacen"]
}

resource "google_compute_firewall" "allow_airflow_ui" {
  name    = "allow-airflow-ui-${var.vm_name}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["airflow-bacen"]
}

# -----------------------------------------------------------------------------
# VM: Ubuntu 22.04 LTS, e2-medium, com Docker + Docker Compose instalados via
# startup script (equivalente ao setup manual documentado no README).
# -----------------------------------------------------------------------------
resource "google_compute_instance" "airflow_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["airflow-bacen"]
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
      nat_ip = google_compute_address.airflow_vm_static_ip.address
    }
  }

  service_account {
    email  = google_service_account.airflow_vm.email
    scopes = ["cloud-platform"]
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
}

# -----------------------------------------------------------------------------
# BigQuery: os 3 datasets da arquitetura Medallion (ver data-pipeline/README.md
# e o README raiz -- Bronze/Silver/Gold)
# -----------------------------------------------------------------------------
resource "google_bigquery_dataset" "bronze" {
  dataset_id  = "${var.bq_dataset_prefix}_bronze"
  location    = var.bq_location
  description = "Camada Bronze: dados brutos ingeridos pelo Airflow (BACEN diario, IBGE semanal)"
  labels      = var.labels
}

resource "google_bigquery_dataset" "silver" {
  dataset_id  = "${var.bq_dataset_prefix}_silver"
  location    = var.bq_location
  description = "Camada Silver: views tratadas/padronizadas geradas pelo dbt (stg_bacen, stg_ibge)"
  labels      = var.labels
}

resource "google_bigquery_dataset" "gold" {
  dataset_id  = "${var.bq_dataset_prefix}_gold"
  location    = var.bq_location
  description = "Camada Gold: Star Schema (dim_tempo, dim_indicador, fato_indicadores) consumido pelo Looker Studio"
  labels      = var.labels
}
