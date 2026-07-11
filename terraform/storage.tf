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

  # Don't pay for half-finished uploads if a seed Job dies mid-pull.
  lifecycle_rule {
    action {
      type = "AbortIncompleteMultipartUpload"
    }
    condition {
      age = 7
    }
  }

  depends_on = [google_project_service.apis]
}

# Bucket access via direct Workload Identity Federation — no GSA or key
# files. Two identities with least privilege:
#   - ollama-seed (the one-off seed Job) writes weights into the bucket
#   - ollama (the serving Deployment) only reads them
locals {
  wi_pool          = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog"
  ollama_principal = "principal://iam.googleapis.com/${local.wi_pool}/subject/ns/nano-llm/sa/ollama"
  seed_principal   = "principal://iam.googleapis.com/${local.wi_pool}/subject/ns/nano-llm/sa/ollama-seed"
}

resource "google_storage_bucket_iam_member" "seed_writes_models" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectAdmin"
  member = local.seed_principal
}

resource "google_storage_bucket_iam_member" "ollama_reads_models" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectViewer"
  member = local.ollama_principal
}
