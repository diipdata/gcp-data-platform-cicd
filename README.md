# GCP Cloud Data Platform: API Resiliente de Cotações com CI/CD Moderno

Plataforma de dados em nuvem projetada para capturar, estruturar e servir cotações de moedas em tempo real (`USD`, `EUR`, `BTC`). O sistema utiliza uma arquitetura híbrida de alta resiliência, segurança avançada sem chaves expostas e esteira de automação ponta a ponta.
<br>

## 🎯 1. O Problema de Negócio (Contexto)

Sistemas financeiros e plataformas de e-commerce modernas dependem de dados de câmbio precisos e ininterruptos para precificação, conversão de moedas e relatórios de BI. Confiar em um único provedor público de dados gratuito gera três riscos críticos para o negócio:

1. **Instabilidade e Quedas (Single Point of Failure):** Se a API externa falhar ou entrar em manutenção, as aplicações integradas quebram.

2. **Bloqueio por Excesso de Requisições (Rate Limiting/Error 429):** Ambientes de nuvem compartilham IPs de saída. APIs gratuitas frequentemente bloqueiam requisições vindas desses IPs devido ao comportamento de "outros vizinhos" hospedados na mesma região.

3. **Falta de Rastreabilidade:** Logs em texto puro dificultam a criação de alertas de auditoria e monitoramento de erros de conformidade em produção.

### A Solução

Esta plataforma resolve essas dores implementando um mecanismo de **Fallback Híbrido** e **Decoupling de Credenciais**, garantindo que o sistema continue respondendo com dados válidos (com taxas de contingência programadas) mesmo sob ataques de Rate Limit ou indisponibilidade total dos provedores principais.
<br>

## 🏗️ 2. Arquitetura do Sistema & Decisões Técnicas

A arquitetura foi desenhada seguindo os pilares do **Google Cloud Architecture Framework**, priorizando Segurança, Eficiência de Custos (**FinOps**) e Resiliência.

### Diagrama de Arquitetura e Fluxo de CI/CD

[Desenvolvedor] ── git push ──> [GitHub Repository]
│
(Dispara GitHub Actions)
▼
┌───────────────────────────────┐
│   Job 1: 🧪 Quality & Lint     │
│   - Ruff Linter & Formatter   │
│   - Pytest com Mocking        │
└───────────────┬───────────────┘
│ (Se passar)
▼
┌───────────────────────────────┐
│   Job 2: 🚀 Build & Deploy     │
│   - Autenticação OIDC (WIF)   │
│   - Build Docker Multi-stage  │
└───────────────┬───────────────┘
│
▼
[Artifact Registry (GCP)]
│
▼
[Google Cloud Run Service]
│
┌─────────────────────────────┴─────────────────────────────┐
▼                                                           ▼
┌──────────────────────────────────┐               ┌──────────────────────────────────┐
│  Caminho A (Secret Manager)      │               │  Caminho B (Fallback Público)    │
│  - Valida API_KEY de memória     │  ──(Falha)──> │  - Consome AwesomeAPI            │
│  - Consome ExchangeRate-API      │               │  - Tratamento Granular (429/50x) │
└──────────────────────────────────┘               └──────────────────────────────────┘
<br>

## 🛠️ 3. Passo a Passo do Sistema (Como Executar)

### 📋 Pré-requisitos
* [Mise](https://mise.jenv.io/) instalado (gerenciador de ambientes)
* [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install) instalado e autenticado
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (v1.5+)

### 💻 1. Configuração do Ambiente Local
```bash
# Clone o repositório
git clone [https://github.com/seu-usuario/gcp-data-platform-cicd.git](https://github.com/seu-usuario/gcp-data-platform-cicd.git)
cd gcp-data-platform-cicd

# Instalar ferramentas locais via mise e sincronizar pacotes do uv

mise install
uv sync
```

### 🧪 2. Rodando Testes e Qualidade Localmente

```bash
# Executa o Linter (Ruff)
uv run ruff check app/

# Executa os testes automatizados com simulação de erros (Mocking)
uv run pytest
```

### 🏗️ 3. Provisionando a Infraestrutura (GCP)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 🔑 4. Armazenando o Segredo no GCP
Substitua com a sua credencial gratuita obtida em ExchangeRate-API:

```bash
echo -n "SUA_API_KEY_AQUI" | gcloud secrets versions add api_key --data-file=-
```
<br>

## 🔗 4. Links Úteis do Projeto

Estrutura de links diretos para navegação rápida pelos componentes essenciais do repositório:

Entrypoint da Aplicação (app/main.py) - Configuração dos endpoints FastAPI.

Motor de Resiliência (app/services/awesome_api_service.py) - Lógica de logs estruturados e inteligência híbrida de Fallback.

Configuração de CI/CD (.github/workflows/deploy.yml) - Pipeline completa do GitHub Actions (Ruff + Pytest + WIF + Deploy).

Infraestrutura do Cloud Run (terraform/cloud_run.tf) - Definição do container com travas FinOps de custo zero e injeção do Secret Manager.

Configuração de Segurança (terraform/wif.tf) - Federação de identidade OIDC entre GitHub e GCP.
<br>

## 🚀 5. Roadmap Técnico (Próximos Passos de Evolução)
Para transformar esta API em uma arquitetura de dados corporativa em larga escala, os seguintes itens estão mapeados para implementação futura:

[ ] Camada de Cache com Cloud Memorystore (Redis): Adicionar uma camada de cache de 5 minutos para as cotações com sucesso, reduzindo a zero a necessidade de bater em APIs externas a cada requisição cliente, otimizando performance e custos.

[ ] Alarme de Custos e Erros Críticos (Cloud Monitoring): Configurar métricas baseadas em logs estruturados para enviar alertas via e-mail/Slack caso o status CRITICAL (API de fallback também fora do ar) seja acionado.

[ ] Persistência de Histórico de Dados (BigQuery): Acoplar um Worker assíncrono para salvar as cotações capturadas de hora em hora dentro de uma tabela particionada do BigQuery para análises históricas de Analytics.