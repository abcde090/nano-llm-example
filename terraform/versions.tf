terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Managed remote state. Create the bucket first with terraform/bootstrap,
  # then uncomment and run:
  #   terraform init -migrate-state -backend-config="bucket=<project>-nano-llm-tfstate"
  # backend "gcs" {
  #   prefix = "nano-llm"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
