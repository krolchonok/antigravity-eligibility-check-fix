"""
mitmproxy-аддон для Antigravity CLI (agy).

Чинит клиентский выбор тарифа: сервер в loadCodeAssist отдаёт standard-tier как
разрешённый/дефолтный (allowedTiers), но помечает free-tier как недоступный
(ineligibleTiers, reasonCode UNSUPPORTED_LOCATION). Клиент из-за этого
обрывается, хотя standard-tier аккаунту доступен. Аддон:

  1. loadCodeAssist (ответ)  — удаляет блок ineligibleTiers;
  2. onboardUser   (запрос)  — ставит tierId=standard-tier (если пришло другое).

Запуск:  mitmdump -s tier-fix.py --listen-port 8085
"""
import json
from mitmproxy import http

HOST = "daily-cloudcode-pa.googleapis.com"
TIER = "standard-tier"


def request(flow: http.HTTPFlow) -> None:
    if flow.request.pretty_host != HOST:
        return
    if flow.request.path.endswith("v1internal:onboardUser"):
        try:
            data = json.loads(flow.request.get_text())
        except Exception:
            return
        if data.get("tierId") != TIER:
            data["tierId"] = TIER
            flow.request.set_text(json.dumps(data))


def response(flow: http.HTTPFlow) -> None:
    if flow.request.pretty_host != HOST:
        return
    if flow.request.path.endswith("v1internal:loadCodeAssist"):
        try:
            data = json.loads(flow.response.get_text())
        except Exception:
            return
        if data.pop("ineligibleTiers", None) is not None:
            flow.response.set_text(json.dumps(data))
