# GKE Autopilot cluster — Google manages nodes, so a tiny LLM workload
# only pays for the pod resources it requests.
resource "google_container_cluster" "nano_llm" {
  name     = var.cluster_name
  location = var.region

  enable_autopilot = true

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Private nodes, public control plane endpoint (simple to reach with kubectl).
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  release_channel {
    channel = "REGULAR"
  }

  # Gateway API for the managed global external load balancer.
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Autopilot clusters use Workload Identity by default; pin it explicitly.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = var.deletion_protection

  depends_on = [google_project_service.apis]
}
