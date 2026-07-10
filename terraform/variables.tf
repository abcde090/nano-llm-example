variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "GCP region for the network and GKE cluster."
  type        = string
  default     = "australia-southeast1"
}

variable "cluster_name" {
  description = "Name of the GKE Autopilot cluster."
  type        = string
  default     = "nano-llm"
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "nano-llm-vpc"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE subnet."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for pods."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "deletion_protection" {
  description = "Protect the cluster from accidental terraform destroy. Disable for throwaway environments."
  type        = bool
  default     = false
}

# --- Public HTTPS edge (Gateway + managed cert). Empty = internal only. ---

variable "domain" {
  description = "Fully qualified domain for the public LLM endpoint (e.g. llm.example.com). Leave empty to skip the load balancer / certificate stack."
  type        = string
  default     = ""
}

# --- Identity-Aware Proxy (requires the project to be in an organization) ---

variable "enable_iap" {
  description = "Put Identity-Aware Proxy in front of the endpoint. Requires var.domain and an organization-owned project."
  type        = bool
  default     = false
}

variable "iap_support_email" {
  description = "Support email shown on the IAP OAuth consent screen. Required when enable_iap = true."
  type        = string
  default     = ""
}

variable "iap_members" {
  description = "IAM members allowed through IAP, e.g. [\"user:you@example.com\", \"domain:example.com\"]."
  type        = list(string)
  default     = []
}

# --- Monitoring ---

variable "alert_email" {
  description = "Email address for Cloud Monitoring alerts. Leave empty to create alert policies without a notification channel."
  type        = string
  default     = ""
}

# --- CI/CD ---

variable "cloudbuild_connection" {
  description = "Full resource name of an existing Cloud Build GitHub connection (projects/.../locations/.../connections/...). Leave empty to skip the push trigger."
  type        = string
  default     = ""
}

variable "github_repo_uri" {
  description = "HTTPS URI of the GitHub repository for the Cloud Build trigger."
  type        = string
  default     = "https://github.com/abcde090/nano-llm-example.git"
}
