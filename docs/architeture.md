

# Arquitetura da Plataforma de Dados - API de Cotações

## 1. Visão Geral do Sistema

O objetivo deste microsserviço é fornecer dados resilientes de cotações de moedas em tempo real para a plataforma de dados, servindo como uma camada de abstração estável sobre provedores de dados externos instáveis (como a AwesomeAPI).

O serviço é construído usando FastAPI, empacotado via Docker, implantado no Google Cloud Run e totalmente gerenciado via Infraestrutura como Código (IaC) com Terraform.

---

## 2. Decisões Técnicas

### 2.1 Gerenciamento de Dependências com `uv`

* **Decisão:** Substituição do `pip`/`poetry` pelo `uv` como gerenciador de pacotes e executor de ambiente.
* **Motivo:** O `uv` reduz o tempo de build no pipeline de CI/CD drasticamente. A suite de testes e instalação de pacotes executa em menos de 1 segundo.
* **Garantia de Idempotência:** Para garantir consistência total entre o ambiente de desenvolvimento local e o runner de CI (GitHub Actions), o comportamento do `pytest` foi embutido diretamente no `pyproject.toml` usando a propriedade `pythonpath = ["."]`. Isso elimina a necessidade de injeção manual de variáveis de ambiente (`PYTHONPATH`) nos scripts do sistema operacional.

### 2.2 Ciclo de Vida e Implantação Híbrida (Terraform + GitHub Actions)

* **Decisão:** O Terraform gerencia toda a fundação da infraestrutura (Cloud Run, IAM, Secret Manager), mas o ciclo de entrega contínua (CI/CD) gerencia as imagens de container.
* **Implementação:** Foi aplicada a regra `ignore_changes` no bloco `lifecycle` do recurso `google_cloud_run_v2_service` para a propriedade `template[0].containers[0].image`.
* **Motivo:** Isso evita o conflito onde o Terraform tenta reverter o container para a imagem placeholder inicial (`hello:latest`) toda vez que um operador roda `terraform apply` localmente após o GitHub Actions já ter feito o deploy da imagem de produção real.

---

## 3. Desafios Enfrentados e Padrões de Resiliência

O principal desafio de engenharia deste microsserviço é lidar com a volatilidade, limites de taxa (Rate Limiting) e quedas completas de APIs de terceiros sem repassar a falha para os sistemas internos ou quebrar a aplicação cliente.

### 3.1 Tratamento Granular de Erros HTTP

Para mitigar isso, implementamos uma lógica de captura estruturada baseada em códigos de status HTTP:

* **Erro 429 (Too Many Requests):** Tratado como comportamento esperado de APIs públicas. O sistema degrada graciosamente, aciona um mecanismo de **Fallback Automático** retornando um valor fixo de segurança (`5.50`) para manter o fluxo de dados operando temporariamente. O log é classificado como `WARNING`.
* **Erros 502, 503, 504 (Provider Down):** Indicam instabilidade severa ou manutenção no provedor externo. O microsserviço ativa o valor de fallback para o cliente, mas o log interno é elevado para a severidade `CRITICAL` no GCP, disparando alertas para o time de engenharia de dados.
* **Erro 404 (Not Found):** Erro de negócio (ex: par de moedas inexistente). Retorna uma mensagem limpa detalhando o erro sem acionar fallbacks, classificado como log de severidade `ERROR`.

---

## 4. Estrutura e Observabilidade (Cloud Logging)

A aplicação utiliza **Logs Estruturados em formato JSON** enviados diretamente para a Saída Padrão (`stdout`). O Google Cloud Logging captura essas linhas e realiza a indexação nativa das chaves.

### Campos Indexados de Alta Performance:

* `severity`: Mapeado dinamicamente (`INFO`, `WARNING`, `ERROR`, `CRITICAL`) para coloração e regras de alerta no GCP.
* `message`: Texto limpo e de fácil leitura humana para exibição rápida no painel (Resumo).
* `payload`: Dicionário contendo o contexto técnico escovado (`status_code`, `url` de origem, e o `response_text` bruto do erro).

Essa estrutura permite que engenheiros realizem auditorias complexas e criem filtros na barra lateral do Log Explorer do GCP com apenas um clique, sem a necessidade de parsing de texto via regex.

---

## 5. Decisões de FinOps (Otimização de Custos)

A arquitetura foi desenhada para operar o mais próximo possível do custo zero ($0.00 USD) durante a fase de desenvolvimento e validação, escalando de forma estritamente controlada.

1. **Escalonamento para Zero (`min_instance_count = 0`):** O Cloud Run desliga completamente todos os containers se não houver requisições ativas. Não há custo de CPU/Memória ociosa.
2. **Limite de Concorrência Rígido (`max_instance_count = 1`):** Evita ataques de negação de serviço (DoS) ou loops infinitos de requisições que poderiam escalar centenas de containers simultâneos, gerando cobranças surpresas na conta do GCP.
3. **Dimensionamento de Recursos Otimizado:** O container Python foi limitado a `1 CPU` e `512Mi` de memória, o que se enquadra confortavelmente dentro da camada gratuita (Always Free) do Google Cloud Run para o volume atual de tráfego.

---

## 6. Segurança e Gerenciamento de Segredos

Nenhuma credencial ou token de API trafega ou fica armazenado no código-fonte.

* **Injeção via Variável de Ambiente:** O Cloud Run utiliza a diretiva `secret_key_ref` para buscar o segredo chamado `api_key` direto do **Google Secret Manager** no momento da inicialização do container, expondo o valor estritamente em memória como a variável `API_KEY`.
* **Princípio do Menor Privilégio:** A permissão de leitura (`roles/secretmanager.secretAccessor`) é concedida exclusivamente para a conta de serviço que executa o container (`compute@developer.gserviceaccount.com`), impedindo que outras identidades ou acessos externos leiam a chave de API de forma não autorizada.

---

## 7. Fluxo de Autenticação e Ciclo de Vida da Requisição

O diagrama abaixo detalha o caminho que uma requisição faz desde a internet até a busca da informação, ilustrando como o Cloud Run e o Secret Manager interagem usando as identidades gerenciadas pelo IAM.

```
[Usuário/Client] 
       │
       ▼ (Acesso Público: allUsers -> roles/run.invoker)
[Google Cloud Run] 
       │
       ├─► (No Bootstrap: Lê a versão 'latest' do segredo)
       │         │
       │         ▼ (IAM: compute@developer... -> roles/secretmanager.secretAccessor)
       │   [Google Secret Manager (api_key)]
       │
       ▼ (Execução: Injeta o token em memória como API_KEY)
[Aplicação FastAPI]
       │
       ├──► [Sucesso] ──► Consulta AwesomeAPI ──► Salva Log INFO (JSON) ──► Retorna 200 OK
       │
       └──► [Falha] ───► Captura HTTPError ──► Salva Log WARN/CRIT (JSON) ─► Retorna Fallback (5.50)

```

---

## 8. Runbook de Operações (Guia de Sobrevivência)

Este guia serve para orientar o time de Engenharia de Dados e SRE em caso de incidentes reportados pelo Cloud Logging.

### Cenário A: Alerta CRITICAL no Log Explorer

* **Sintoma:** O log apresenta severidade `CRITICAL` com a mensagem `"O provedor de dados está instável ou em manutenção."`.
* **O que significa:** A AwesomeAPI está fora do ar (erros 500/503). O sistema ativou o `fallback_valor` de 5.50 de forma automática. Os dados salvos no banco ou entregues nas tabelas finais estarão estáticos.
* **Ação Recomendada:** 1. Verificar o status da API externa (AwesomeAPI).
2. Caso o provedor passe mais de 2 horas fora do ar, avaliar junto ao time de negócio a necessidade de atualizar o valor do fallback diretamente no código para refletir a realidade macroeconômica do dia.

### Cenário B: Alerta ERROR com status 404

* **Sintoma:** O log apresenta severidade `ERROR` com a mensagem `"O par de moedas 'XYZ-BRL' não foi encontrado na API."`.
* **O que significa:** Algum sistema interno tentou consultar um ticker ou par de moedas que a AwesomeAPI não suporta ou que foi digitado incorretamente.
* **Ação Recomendada:**
1. Verificar o payload do log para identificar qual microsserviço ou pipeline de ingestão disparou a query inválida.
2. Corrigir o parâmetro `pair` na aplicação de origem.



### Cenário C: Alteração ou Expiração da Chave de API

* **Sintoma:** A API externa começa a retornar erro `401 Unauthorized` ou `403 Forbidden`.
* **O que fazer:** Não é necessário alterar o código ou rodar o Terraform novamente. Basta gerar uma nova versão do segredo via CLI:
```bash
echo -n "NOVO_TOKEN_AQUI" | gcloud secrets versions add api_key --data-file=-

```


O Cloud Run v2 atualizará os containers automaticamente para ler a versão `latest` em poucos segundos.
