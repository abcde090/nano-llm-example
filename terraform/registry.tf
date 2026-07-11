# Artifact Registry remote repository that proxies and caches Docker Hub.
# Nodes pull ollama/ollama through Google's registry instead of Docker Hub
# directly: no Hub rate limits, and images get vulnerability scanning.
#
# Image path becomes:
#   ${region}-docker.pkg.dev/${project_id}/dockerhub/ollama/ollama:<tag>
resource "google_artifact_registry_repository" "dockerhub_remote" {
  location      = var.region
  repository_id = "dockerhub"
  description   = "Remote repository proxying Docker Hub"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "Docker Hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  depends_on = [google_project_service.apis]
}

# Autopilot nodes pull as the Compute Engine default service account; grant it
# read on this repository explicitly so pulls keep working on projects where
# the default SA's legacy Editor role has been removed.
resource "google_artifact_registry_repository_iam_member" "nodes_pull" {
  project    = var.project_id
  location   = google_artifact_registry_repository.dockerhub_remote.location
  repository = google_artifact_registry_repository.dockerhub_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}
