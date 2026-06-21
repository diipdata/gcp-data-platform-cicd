import requests
from datetime import datetime

class AwesomeAPIService:
    BASE_URL = "https://economia.awesomeapi.com.br/last"

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
        except Exception as e:
            return {"error": f"Erro ao buscar cotação na AwesomeAPI: {str(e)}"}