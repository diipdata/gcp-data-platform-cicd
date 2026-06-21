from fastapi.testclient import TestClient
from app.main import app
import unittest.mock as mock

client = TestClient(app)

def test_health_endpoint():
    """Testa se o endpoint de health check responde corretamente"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

@mock.patch("app.services.awesome_api_service.requests.get")
def test_get_usd_success(mock_get):
    """Testa o endpoint /usd simulando um retorno de sucesso da API externa"""
    # Simulamos o JSON que a AwesomeAPI retornaria
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = {
        "USDBRL": {
            "name": "Dólar Americano/Real Brasileiro",
            "bid": "5.45",
            "ask": "5.46",
            "pctChange": "0.12",
            "create_date": "2026-06-21 12:00:00"
        }
    }

    response = client.get("/usd")
    assert response.status_code == 200
    assert response.json()["valor_compra"] == 5.45
    assert response.json()["moeda"] == "Dólar Americano/Real Brasileiro"

@mock.patch("app.services.awesome_api_service.requests.get")
def test_get_usd_rate_limited(mock_get):
    """Testa se o nosso fallback de resiliência funciona quando a API externa dá 429"""
    # Simulamos o erro 429 Too Many Requests
    from requests.exceptions import HTTPError
    mock_response = mock.Mock()
    mock_response.status_code = 429
    mock_response.text = "Too Many Requests"
    
    # Fazemos o raise_for_status disparar o HTTPError
    mock_get.return_value.raise_for_status.side_effect = HTTPError(response=mock_response)

    response = client.get("/usd")
    assert response.status_code == 200 # Nossa API trata o erro e responde 200 com o fallback!
    assert response.json()["status"] == "rate_limited"
    assert "fallback_valor" in response.json()
