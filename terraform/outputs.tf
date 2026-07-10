output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.nano_llm.name
}

output "cluster_region" {
  description = "GKE cluster region."
  value       = var.region
}

output "get_credentials_command" {
  description = "Run this to configure kubectl."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.nano_llm.name} --region ${var.region} --project ${var.project_id}"
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.vpc.name
}
