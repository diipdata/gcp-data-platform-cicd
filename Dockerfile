# Estágio 1: Build e Instalação de Dependências
# ========
FROM python:3.12-slim AS builder

WORKDIR /app

# Instala o utilitário 'uv' copiando o binário oficial mais recente
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copia os arquivos de especificação de dependências antes do código
# Isso permite que o Docker faça cache dessa camada se os pacotes não mudarem
COPY pyproject.toml uv.lock ./

# Sincroniza as dependências em um ambiente virtual (.venv) sem pacotes de desenvolvimento
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev


# Estágio 2: Imagem Final de Produção (Super leve)
# ========
FROM python:3.12-slim

WORKDIR /app

# Copia apenas o ambiente virtual pronto do estágio de build anterior
COPY --from=builder /app/.venv /app/.venv

# Copia o código da nossa API
COPY app/ ./app

# Adiciona o ambiente virtual do 'uv' no PATH do sistema operacional do container
ENV PATH="/app/.venv/bin:$PATH"

# Porta padrão exposta pelo Cloud Run
EXPOSE 8080

# Executa o uvicorn apontando para o nosso app.main:app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]