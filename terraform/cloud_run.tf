resource "google_cloud_run_v2_service" "api" {
  depends_on = [google_project_service.services]
  name       = "data-platform-api"
  location   = var.region
  ingress    = "INGRESS_TRAFFIC_ALL"

  template {
    # FinOps: Limita o escalonamento para no máximo 1 instância ativa por vez
    scaling {
      max_instance_count = 1
      min_instance_count = 0 # Permite ir para zero quando não houver tráfego (grátis)
    }

    containers {
      # Imagem placeholder inicial, pois a imagem real será enviada pelo GitHub Actions
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi" # FinOps: Memória otimizada para containers Python leves
        }
      }

      ports {
        container_port = 8080
      }
    }
  }

  # FinOps: Aplica as tags de custo no recurso do Cloud Run
  labels = var.labels
}

# Permite que qualquer pessoa na internet acesse a API pública (Não autenticado)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.viewer"
  member   = "allUsers"
}
