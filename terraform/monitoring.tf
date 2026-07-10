# Observability via managed services. GKE Autopilot ships with Cloud Logging,
# Cloud Monitoring, and Google Cloud Managed Service for Prometheus enabled —
# kubelet/cAdvisor container metrics are collected automatically with nothing
# to install. (Ollama exposes no /metrics endpoint of its own; if you add an
# exporter sidecar later, a PodMonitoring resource is all it takes to scrape
# it into Managed Prometheus.)

resource "google_monitoring_notification_channel" "email" {
  count = var.alert_email != "" ? 1 : 0

  display_name = "nano-llm alerts"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.apis]
}

# Page when the ollama container crash-loops.
resource "google_monitoring_alert_policy" "ollama_restarts" {
  display_name = "nano-llm: ollama restarting"
  combiner     = "OR"

  conditions {
    display_name = "ollama container restarts > 2 in 10m"

    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"ollama\" AND metric.type = \"kubernetes.io/container/restart_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 2
      duration        = "0s"

      aggregations {
        alignment_period   = "600s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].id

  depends_on = [google_project_service.apis]
}

# Warn before the model no longer fits in memory.
resource "google_monitoring_alert_policy" "ollama_memory" {
  display_name = "nano-llm: ollama memory > 90%"
  combiner     = "OR"

  conditions {
    display_name = "ollama memory utilisation"

    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"ollama\" AND metric.type = \"kubernetes.io/container/memory/limit_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.9
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].id

  depends_on = [google_project_service.apis]
}
