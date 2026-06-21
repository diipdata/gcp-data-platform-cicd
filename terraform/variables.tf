variable "project_id" {
  type        = string
  description = "O ID do seu projeto no GCP"
  default     = "gcp-data-platform-26"
}

variable "region" {
  type        = string
  description = "Região onde os recursos serão provisionados"
  default     = "us-central1"
}

variable "labels" {
  type        = map(string)
  description = "Labels para fins de FinOps e alocação de custos"
  default = {
    environment = "production"
    project     = "gcp-data-platform"
    managed_by  = "terraform"
  }
}
