# Variável para indicar qual repositório do GitHub tem permissão de se conectar
variable "github_repository" {
  type        = string
  description = "diipdata/gcp-data-platform-cicd"
  default     = "diipdata/gcp-data-platform-cicd"
}

# 1. Cria o Pool de Identidade de Carga de Trabalho (Workload Identity Pool)

resource "google_iam_workload_identity_pool" "github_pool" {
  depends_on                = [google_project_service.services]
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool para autenticacao do GitHub Actions via OIDC"
}

# 2. Cria o Provedor (Provider) dentro do Pool
# Aqui dizemos ao GCP que confiamos no emissor de tokens do GitHub (token.actions.githubusercontent.com)

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions Provider"
  
  # Mapeamento de Atributos: Traduz as claims do JWT do GitHub para o IAM do GCP
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
  }

  # Correção do Erro 400: Garante que o provedor valide se a requisição possui a claim de repositório
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# 3. Vincula o Provedor do GitHub à Service Account existente
# Esta regra diz: "Se o token vier do repositório X do GitHub, permita que ele assuma a nossa Service Account"

resource "google_service_account_iam_member" "wif_user" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  
  # Condição estrita de segurança: apenas o repositório configurado pode assumir a conta
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
}