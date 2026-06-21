output "repository_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
  description = "URL do Artifact Registry para o push do Docker"
}

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github_provider.name
  description = "O identificador completo do Workload Identity Provider (Copie para a pipeline)"
}

output "service_account_email" {
  value       = google_service_account.github_actions.email
  description = "O e-mail da Service Account que o GitHub irá assumir"
}
