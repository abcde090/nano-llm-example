# GCS bucket holding the Ollama model store. Pods mount it with the GCS FUSE
# CSI driver (built into GKE Autopilot), so:
#   - model weights survive pod/node churn without a PVC,
#   - multiple replicas share one read-mostly copy (no ReadWriteOnce limit),
#   - a one-off seed Job pulls the model into the bucket once.
resource "google_storage_bucket" "models" {
  name                        = "${var.project_id}-nano-llm-models"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true # example repo: allow destroy with objects inside

  depends_on = [google_project_service.apis]
}

# Grant the ollama Kubernetes ServiceAccount access to the bucket via direct
# Workload Identity Federation — no GSA or key files needed. The principal
# maps to ServiceAccount `ollama` in namespace `nano-llm`.
locals {
  ollama_wi_principal = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/nano-llm/sa/ollama"
}

resource "google_storage_bucket_iam_member" "ollama_models_admin" {
  bucket = google_storage_bucket.models.name
  # objectAdmin (not just viewer) because the seed Job writes weights into the
  # bucket and the server updates manifest metadata under the same prefix.
  role   = "roles/storage.objectAdmin"
  member = local.ollama_wi_principal
}
