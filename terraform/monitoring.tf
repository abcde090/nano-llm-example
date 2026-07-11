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

# Managed uptime check against the public endpoint, probing the
# OpenAI-compatible model list from Google's global checkers. Only created
# when the edge stack is up and IAP is off (IAP would answer 302/401 to
# unauthenticated checkers and make the check permanently red).
resource "google_monitoring_uptime_check_config" "llm" {
  count = var.domain != "" && !var.enable_iap ? 1 : 0

  display_name = "nano-llm endpoint"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = "/v1/models"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "llm_uptime" {
  count = var.domain != "" && !var.enable_iap ? 1 : 0

  display_name = "nano-llm: public endpoint down"
  combiner     = "OR"

  conditions {
    display_name = "uptime check failing"

    condition_threshold {
      filter          = "metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type = \"uptime_url\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.llm[0].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "600s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.host"]
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].id
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
