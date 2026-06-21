terraform {
  required_version = ">= 1.8.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = "${var.region}-a"
}


# Ativação de APIs necessárias
# ------------------------------------------------------------------------------

# Lista de serviços que precisam ser habilitados no projeto
variable "gcp_services" {
  type = list(string)
  default = [
    "iam.googleapis.com",                  # Gerenciamento de acessos
    "artifactregistry.googleapis.com",     # Armazenamento do Docker
    "run.googleapis.com",                  # Execução da API
    "iamcredentials.googleapis.com"        # Necessário para o GitHub OIDC (Segurança)
  ]
}

resource "google_project_service" "services" {
  for_each           = toset(var.gcp_services)
  service            = each.value
  disable_on_destroy = false # Evita desligar acidentalmente e quebrar dependências
}