resource "google_artifact_registry_repository" "docker_repo" {
  depends_on    = [google_project_service.services]
  location      = var.region
  repository_id = "data-platform-repository"
  description   = "Repositorio Docker para a API de Cotacoes"
  format        = "DOCKER"

  # FinOps: Tags ajudam a rastrear os custos de armazenamento no Billing do GCP
  labels = var.labels
}
