output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.nano_llm.name
}

output "cluster_region" {
  description = "GKE cluster region."
  value       = var.region
}

output "project_id" {
  description = "GCP project ID (consumed by the manifest templating in the Makefile)."
  value       = var.project_id
}

output "get_credentials_command" {
  description = "Run this to configure kubectl."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.nano_llm.name} --region ${var.region} --project ${var.project_id}"
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.vpc.name
}

output "models_bucket" {
  description = "GCS bucket holding the Ollama model store."
  value       = google_storage_bucket.models.name
}

output "artifact_registry_prefix" {
  description = "Image prefix for the Docker Hub remote repository."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.dockerhub_remote.repository_id}"
}

output "artifact_registry_apps" {
  description = "Image prefix for first-party application images."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.apps.repository_id}"
}

output "gateway_ip" {
  description = "Static IP of the public gateway (empty when var.domain is unset)."
  value       = var.domain != "" ? google_compute_global_address.gateway[0].address : ""
}

output "domain" {
  description = "Configured public domain (empty when the edge stack is disabled)."
  value       = var.domain
}

output "dns_authorization_record" {
  description = "CNAME record to create so Certificate Manager can issue the certificate."
  value = var.domain != "" ? {
    name = google_certificate_manager_dns_authorization.llm[0].dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.llm[0].dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.llm[0].dns_resource_record[0].data
  } : null
}

output "iap_enabled" {
  description = "Whether IAP is configured."
  value       = var.enable_iap
}

output "iap_client_id" {
  description = "OAuth client ID for IAP (empty when disabled)."
  value       = var.enable_iap ? google_iap_client.llm[0].client_id : ""
}

output "clouddeploy_pipeline" {
  description = "Cloud Deploy delivery pipeline name."
  value       = google_clouddeploy_delivery_pipeline.llm.name
}
