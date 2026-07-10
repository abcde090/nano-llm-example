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
