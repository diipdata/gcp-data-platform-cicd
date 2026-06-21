import requests
import json
import logging
import sys
from datetime import datetime

# Configuração básica do logger para enviar para a saída padrão (stdout)
logger = logging.getLogger("data-platform")
logger.setLevel(logging.INFO)

# Handler simples para garantir que o formato seja exatamente um JSON puro por linha
handler = logging.StreamHandler(sys.stdout)
logger.addHandler(handler)

class AwesomeAPIService:
    BASE_URL = "https://economia.awesomeapi.com.br/last"

    @staticmethod
    def log_gcp(severity: str, message: str, payload: dict = None):
        """Formata o log no padrão que o Google Cloud Logging indexa nativamente"""
        log_entry = {
            "severity": severity,   # INFO, WARNING, ERROR, CRITICAL
            "message": message,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        if payload:
            log_entry["payload"] = payload
            
        # Imprime o JSON em uma única linha (padrão exigido pelo GCP Cloud Logging)
        print(json.dumps(log_entry))

    @staticmethod
    def get_currency_rate(pair: str) -> dict:
        """
        Busca a cotação em tempo real de um par de moedas.
        Exemplo de pair: 'USD-BRL', 'EUR-BRL'
        """
        url = f"{AwesomeAPIService.BASE_URL}/{pair}"
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            
            # A API retorna um JSON dinâmico baseado no par, ex: {"USDBRL": {...}}
            key = pair.replace("-", "")
            data = response.json()[key]
            
            # Converte a string de timestamp/data para o formato padrão AAAA-MM-DD
            create_date = data.get("create_date", "")
            if create_date:
                # O formato retornado geralmente é "AAAA-MM-DD HH:MM:SS"
                date_part = create_date.split(" ")[0]
            else:
                date_part = datetime.today().strftime('%Y-%m-%d')

            return {
                "moeda": data.get("name"),
                "valor_compra": float(data.get("bid")),
                "valor_venda": float(data.get("ask")),
                "variacao": float(data.get("pctChange")),
                "data": date_part
            }
        except requests.exceptions.HTTPError as http_err:
            status_code = http_err.response.status_code
            error_msg = f"Erro HTTP {status_code} ao acessar AwesomeAPI para o par {pair}"
            
            # 1. Definição inteligente de Severidade do Log
            severity = "ERROR"
            if status_code == 429:
                severity = "WARNING"
            elif status_code in [502, 503, 504]:
                severity = "CRITICAL" # API deles caiu feio, precisamos saber urgente
                
            AwesomeAPIService.log_gcp(
                severity=severity,
                message=error_msg,
                payload={"status_code": status_code, "url": url, "response_text": http_err.response.text}
            )
            
            # 2. Tratamento granular das respostas (Resiliência)
            if status_code == 429:
                return {
                    "error": "Serviço temporariamente indisponível (Limite de requisições excedido).",
                    "status": "rate_limited",
                    "fallback_valor": 5.50
                }
                
            elif status_code in [500, 502, 503, 504]:
                return {
                    "error": "O provedor de dados está instável ou em manutenção.",
                    "status": "provider_down",
                    "fallback_valor": 5.50 # Se o serviço caiu, o fallback também te salva aqui!
                }
                
            elif status_code == 404:
                return {
                    "error": f"O par de moedas '{pair}' não foi encontrado na API.",
                    "status": "not_found"
                }
            
            # Qualquer outro erro HTTP genérico (ex: 400 Bad Request, 403 Forbidden)
            return {"error": "Erro de comunicação com o provedor de dados externo.", "status": "http_error"}