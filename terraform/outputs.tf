output "vm_external_ip" {
  description = "IP externo estatico da VM (SSH e UI do Airflow na porta 8080)"
  value       = google_compute_address.airflow_static_ip.address
}

output "vm_name" {
  value = google_compute_instance.airflow_vm.name
}

output "airflow_bigquery_service_account_email" {
  description = "E-mail da service account usada dentro do container do Airflow para acessar o BigQuery"
  value       = google_service_account.airflow_bigquery.email
}

output "bigquery_datasets" {
  value = {
    bronze = google_bigquery_dataset.bronze.dataset_id
    silver = google_bigquery_dataset.silver.dataset_id
    gold   = google_bigquery_dataset.gold.dataset_id
  }
}
