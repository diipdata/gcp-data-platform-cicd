# 1. Cria o cofre para guardar a API Key
resource "google_secret_manager_secret" "api_key" {
  depends_on = [google_project_service.services]
  secret_id  = "api_key"

  replication {
    auto {}
  }

  labels = var.labels
}

# 2. Permissão: Permite que a Service Account do Cloud Run LEIA o segredo
# Nota: O Cloud Run v2 usa a Compute Engine Default Service Account por padrão se não especificarmos uma,
# mas como criamos uma SA para o GitHub, vamos usar uma boa prática: fazer o Cloud Run rodar sob sua própria identidade corporativa.

data "google_project" "project" {}

resource "google_secret_manager_secret_iam_member" "cloud_run_secret_access" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  # Conta padrão que executa o Cloud Run
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# 3. Cria a primeira versão do segredo para o Cloud Run não falhar no deploy inicial
resource "google_secret_manager_secret_version" "api_key_version" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = "placeholder_keapi_keyy_value" # O valor real vamos atualizar depois manualmente no console
}