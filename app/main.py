from fastapi import FastAPI
from app.services.awesome_api_service import AwesomeAPIService

app = FastAPI(title="GCP Data Platform API - Cotações em Tempo Real")

@app.get("/health")
def health():
    return {"status": "healthy", "environment": "production", "source": "AwesomeAPI"}

@app.get("/usd")
def get_usd():
    """Retorna a cotação atualizada do Dólar Americano em relação ao Real (BRL)."""
    return AwesomeAPIService.get_currency_rate("USD-BRL")

@app.get("/eur")
def get_eur():
    """Retorna a cotação atualizada do Euro em relação ao Real (BRL)."""
    return AwesomeAPIService.get_currency_rate("EUR-BRL")

@app.get("/btc")
def get_btc():
    """Retorna a cotação atualizada do Bitcoin em relação ao Real (BRL)."""
    return AwesomeAPIService.get_currency_rate("BTC-BRL")