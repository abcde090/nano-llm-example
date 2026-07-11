# One-time bootstrap: creates the GCS bucket that stores Terraform state for
# the main configuration. Run this first with local state, then initialise
# the main config against the bucket:
#
#   cd terraform/bootstrap
#   terraform init && terraform apply -var project_id=YOUR_PROJECT
#   cd ..
#   terraform init -migrate-state \
#     -backend-config="bucket=YOUR_PROJECT-nano-llm-tfstate"
#
# (Uncomment the backend "gcs" block in ../versions.tf first.)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Bucket location."
  type        = string
  default     = "australia-southeast1"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-nano-llm-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}

output "state_bucket" {
  value = google_storage_bucket.tfstate.name
}
