# Managed CI/CD: Cloud Build runs the pipeline in cloudbuild.yaml, and
# Cloud Deploy rolls the rendered manifests out to the GKE cluster.
#
# The delivery pipeline and target are always created (they cost nothing at
# rest). The Cloud Build trigger needs a GitHub connection, which involves a
# one-time interactive OAuth handshake in the console — so it is opt-in via
# var.cloudbuild_connection.

resource "google_clouddeploy_target" "prod" {
  name     = "nano-llm-prod"
  location = var.region

  gke {
    cluster = google_container_cluster.nano_llm.id
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }

  depends_on = [google_project_service.apis]
}

resource "google_clouddeploy_delivery_pipeline" "llm" {
  name     = "nano-llm"
  location = var.region

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.prod.name
    }
  }

  depends_on = [google_project_service.apis]
}

# --- Service accounts and IAM ---

resource "google_service_account" "clouddeploy" {
  account_id   = "nano-llm-clouddeploy"
  display_name = "Cloud Deploy execution for nano-llm"
}

resource "google_project_iam_member" "clouddeploy_roles" {
  for_each = toset([
    "roles/clouddeploy.jobRunner",
    "roles/container.developer",
    "roles/logging.logWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.clouddeploy.email}"
}

resource "google_service_account" "cloudbuild" {
  account_id   = "nano-llm-cloudbuild"
  display_name = "Cloud Build for nano-llm"
}

resource "google_project_iam_member" "cloudbuild_roles" {
  for_each = toset([
    "roles/clouddeploy.releaser",
    "roles/logging.logWriter",
    "roles/storage.objectAdmin", # release source + build artifacts
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Cloud Build must be able to act as the Cloud Deploy execution SA when
# creating releases.
resource "google_service_account_iam_member" "cloudbuild_uses_clouddeploy" {
  service_account_id = google_service_account.clouddeploy.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# --- Push trigger (opt-in: needs an existing Cloud Build GitHub connection) ---

resource "google_cloudbuildv2_repository" "repo" {
  count = var.cloudbuild_connection != "" ? 1 : 0

  name              = "nano-llm-example"
  location          = var.region
  parent_connection = var.cloudbuild_connection
  remote_uri        = var.github_repo_uri
}

resource "google_cloudbuild_trigger" "main" {
  count = var.cloudbuild_connection != "" ? 1 : 0

  name            = "nano-llm-main"
  location        = var.region
  service_account = google_service_account.cloudbuild.id
  filename        = "cloudbuild.yaml"

  repository_event_config {
    repository = google_cloudbuildv2_repository.repo[0].id
    push {
      branch = "^main$"
    }
  }

  substitutions = {
    _REGION   = var.region
    _PIPELINE = google_clouddeploy_delivery_pipeline.llm.name
  }
}
