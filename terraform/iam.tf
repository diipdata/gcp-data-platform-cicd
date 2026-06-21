# Cria a conta de serviço que o GitHub Actions vai assumir
resource "google_service_account" "github_actions" {
  depends_on   = [google_project_service.services]
  account_id   = "github-actions-deployer"
  display_name = "Service Account para a pipeline de CI/CD do GitHub"
}

# Permissão 1: Escrever imagens no Artifact Registry
resource "google_artifact_registry_repository_iam_member" "registry_writer" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_actions.email}"
}

# Permissão 2: Gerenciar o deploy no Cloud Run
resource "google_cloud_run_v2_service_iam_member" "run_admin" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.github_actions.email}"
}

# Permissão 3: Agir como o usuário da Service Account do Cloud Run
resource "google_project_iam_member" "sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
