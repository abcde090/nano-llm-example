# Public HTTPS edge for the LLM endpoint, active only when var.domain is set.
# The Gateway/HTTPRoute themselves live in k8s/gateway.yaml; Terraform owns
# the pieces GKE can't create declaratively: the static IP, the
# Certificate Manager cert + map, Cloud Armor, and the IAP OAuth client.

locals {
  edge_enabled = var.domain != ""
}

# Static global anycast IP referenced by name from the Gateway manifest.
resource "google_compute_global_address" "gateway" {
  count = local.edge_enabled ? 1 : 0

  name = "nano-llm-ip"

  depends_on = [google_project_service.apis]
}

# --- Google-managed TLS certificate (Certificate Manager, DNS authorization) ---

resource "google_certificate_manager_dns_authorization" "llm" {
  count = local.edge_enabled ? 1 : 0

  name   = "nano-llm-dns-auth"
  domain = var.domain

  depends_on = [google_project_service.apis]
}

resource "google_certificate_manager_certificate" "llm" {
  count = local.edge_enabled ? 1 : 0

  name = "nano-llm-cert"

  managed {
    domains            = [var.domain]
    dns_authorizations = [google_certificate_manager_dns_authorization.llm[0].id]
  }
}

# The Gateway references this map via the networking.gke.io/certmap annotation.
resource "google_certificate_manager_certificate_map" "llm" {
  count = local.edge_enabled ? 1 : 0

  name = "nano-llm-cert-map"

  depends_on = [google_project_service.apis]
}

resource "google_certificate_manager_certificate_map_entry" "llm" {
  count = local.edge_enabled ? 1 : 0

  name         = "nano-llm-cert-map-entry"
  map          = google_certificate_manager_certificate_map.llm[0].name
  certificates = [google_certificate_manager_certificate.llm[0].id]
  hostname     = var.domain
}

# --- Cloud Armor: managed WAF / rate limiting on the load balancer ---
# Attached to the backend via the GCPBackendPolicy in k8s/. Created even
# without a domain so the policy name is stable for the manifests.

resource "google_compute_security_policy" "llm" {
  name        = "nano-llm-armor"
  description = "Rate-limit the public LLM endpoint"

  # Throttle each client IP to 60 requests/minute.
  rule {
    action   = "throttle"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 60
        interval_sec = 60
      }
    }
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default allow"
  }

  depends_on = [google_project_service.apis]
}

# --- Identity-Aware Proxy: Google-managed auth in front of the endpoint ---
# Requires the project to be inside a Google Cloud organization (IAP brand
# constraint), so it is opt-in via var.enable_iap.

resource "google_iap_brand" "llm" {
  count = var.enable_iap ? 1 : 0

  support_email     = var.iap_support_email
  application_title = "nano-llm"

  depends_on = [google_project_service.apis]
}

resource "google_iap_client" "llm" {
  count = var.enable_iap ? 1 : 0

  display_name = "nano-llm-gateway"
  brand        = google_iap_brand.llm[0].name
}

# Who is allowed through IAP.
resource "google_iap_web_iam_member" "allowed" {
  for_each = var.enable_iap ? toset(var.iap_members) : toset([])

  role   = "roles/iap.httpsResourceAccessor"
  member = each.value

  depends_on = [google_project_service.apis]
}

# Keep the OAuth client secret in Secret Manager; `make deploy-gateway`
# materialises it as the Kubernetes Secret the GCPBackendPolicy references.
resource "google_secret_manager_secret" "iap_client_secret" {
  count = var.enable_iap ? 1 : 0

  secret_id = "nano-llm-iap-client-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "iap_client_secret" {
  count = var.enable_iap ? 1 : 0

  secret      = google_secret_manager_secret.iap_client_secret[0].id
  secret_data = google_iap_client.llm[0].secret
}
