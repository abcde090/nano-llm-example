terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # For team use, swap local state for a GCS backend:
  # backend "gcs" {
  #   bucket = "your-tf-state-bucket"
  #   prefix = "nano-llm"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
