#!/usr/bin/env python3
"""Controlled one-source RSS import for Alice News DEV. Never stores admin tokens."""
import argparse
import getpass
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

DEFAULT_URL = "http://127.0.0.1:19090"
MAX_JSON_BYTES = 1_000_000


class SmokeError(Exception):
    """A user-facing safe error (never includes credentials or response bodies)."""


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def validate_base_url(value):
    parsed = urllib.parse.urlsplit(value)
    if (parsed.scheme != "http" or parsed.hostname not in ("localhost", "127.0.0.1", "::1")
            or parsed.username is not None or parsed.password is not None
            or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
        raise SmokeError("Adres API musi wskazywać wyłącznie lokalny HTTP (127.0.0.1/localhost/::1).")
    try:
        port = parsed.port
    except ValueError as exc:
        raise SmokeError("Nieprawidłowy port API.") from exc
    if port is None:
        raise SmokeError("Podaj jawnie lokalny port API, np. http://127.0.0.1:19090")
    return value.rstrip("/")


def request_json(base_url, path, *, method="GET", token=None):
    if not path.startswith("/") or path.startswith("//"):
        raise SmokeError("Nieprawidłowa ścieżka API.")
    headers = {"Accept": "application/json"}
    if token is not None:
        if not token or "\r" in token or "\n" in token:
            raise SmokeError("Token administracyjny jest pusty lub nieprawidłowy.")
        headers["X-News-Admin-Token"] = token
    request = urllib.request.Request(base_url + path,
                                     data=b"" if method == "POST" else None,
                                     headers=headers, method=method)
    # Never relay an admin token through an HTTP proxy or redirect.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=40 if method == "POST" else 10) as response:
            body = response.read(MAX_JSON_BYTES + 1)
    except urllib.error.HTTPError as exc:
        raise SmokeError(f"{method} {path}: HTTP {exc.code}. Sprawdź logi news-service.") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise SmokeError(f"{method} {path}: brak połączenia lub przekroczony czas.") from exc
    if len(body) > MAX_JSON_BYTES:
        raise SmokeError(f"{method} {path}: odpowiedź przekracza limit rozmiaru.")
    try:
        return json.loads(body)
    except (ValueError, UnicodeDecodeError) as exc:
        raise SmokeError(f"{method} {path}: niepoprawna odpowiedź JSON.") from exc


def choose_source(sources, source_id, input_fn):
    enabled = [s for s in sources if isinstance(s, dict) and s.get("enabled") is True]
    if not enabled:
        raise SmokeError("Brak aktywnych źródeł RSS. Sprawdź migrację V2 lub konfigurację źródeł.")
    print("Aktywne źródła:")
    for index, source in enumerate(enabled, 1):
        print(f"  {index}. {source.get('name', '?')} [{source.get('category', '?')}] — {source.get('id', '?')}")
    if source_id is not None:
        try:
            wanted = uuid.UUID(source_id)
        except ValueError as exc:
            raise SmokeError("--source-id musi być poprawnym UUID.") from exc
        for source in enabled:
            if str(source.get("id")) == str(wanted):
                return source
        raise SmokeError("Podane źródło nie istnieje lub jest wyłączone.")
    selection = input_fn("Numer jednego źródła do testowego importu (Enter = anuluj): ").strip()
    if not selection.isdecimal():
        raise SmokeError("Anulowano import (nie wybrano numeru źródła).")
    index = int(selection)
    if not 1 <= index <= len(enabled):
        raise SmokeError("Numer źródła jest poza zakresem.")
    return enabled[index - 1]


def run(base_url=DEFAULT_URL, *, source_id=None, list_only=False,
        input_fn=input, secret_fn=getpass.getpass, request_fn=request_json):
    base_url = validate_base_url(base_url)
    readiness = request_fn(base_url, "/actuator/health/readiness")
    if not isinstance(readiness, dict) or readiness.get("status") != "UP":
        raise SmokeError("News nie zgłasza stanu UP; przerwano przed importem.")
    # Ensure the previously failing endpoint is healthy BEFORE a state-changing POST.
    articles = request_fn(base_url, "/api/news/articles?limit=1")
    if not isinstance(articles, list):
        raise SmokeError("Niepoprawna odpowiedź API /articles; przerwano przed importem.")
    sources = request_fn(base_url, "/api/news/sources")
    if not isinstance(sources, list):
        raise SmokeError("Niepoprawna odpowiedź API /sources; przerwano przed importem.")
    if list_only:
        active = [s for s in sources if isinstance(s, dict) and s.get("enabled") is True]
        print(f"News UP; aktywne źródła: {len(active)}")
        for source in active:
            print(f"  {source.get('name', '?')} [{source.get('category', '?')}] — {source.get('id', '?')}")
        return 0

    chosen = choose_source(sources, source_id, input_fn)
    ident = str(chosen["id"])
    if input_fn(f"Importować WYŁĄCZNIE źródło '{chosen.get('name')}' ({ident})? Wpisz TAK: ").strip() != "TAK":
        raise SmokeError("Anulowano import; niczego nie zmieniono.")
    token = secret_fn("NEWS_ADMIN_TOKEN (ukryty): ")
    if not token or not token.strip():
        raise SmokeError("Brak tokenu; niczego nie wysłano.")
    result = request_fn(base_url, "/api/news/admin/import/" + ident, method="POST", token=token)
    if not isinstance(result, dict) or str(result.get("sourceId")) != ident:
        raise SmokeError("API importu zwróciło niewłaściwy identyfikator źródła.")
    seen, inserted = result.get("seen"), result.get("inserted")
    if (type(seen) is not int or type(inserted) is not int or seen < 0
            or inserted < 0 or inserted > seen):
        raise SmokeError("API importu zwróciło nieprawidłowe liczniki.")
    print(f"Źródło: {result.get('source', chosen.get('name'))}; odczytane: {seen}; dodane: {inserted}")
    if result.get("error"):
        print("BŁĄD IMPORTU: " + str(result["error"])[:300], file=sys.stderr)
        return 1
    after = request_fn(base_url, "/api/news/articles?limit=100")
    if not isinstance(after, list):
        raise SmokeError("Import odpowiedział, ale odczyt listy artykułów nie działa.")
    print(f"API artykułów działa; zwróciło {len(after)} rekordów (limit 100).")
    if seen == 0:
        print("UWAGA: źródło nie zwróciło żadnych artykułów; import wymaga weryfikacji.")
        return 2
    if inserted == 0:
        print("Brak nowych wpisów — mogły już istnieć (deduplikacja po URL/GUID).")
    else:
        print("Import jednego źródła zakończony bez raportowanego błędu.")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Kontrolowany import jednego RSS do Alice News DEV")
    parser.add_argument("--url", default=DEFAULT_URL, help="Lokalny adres API (domyślnie 127.0.0.1:19090)")
    parser.add_argument("--list", action="store_true", help="Tylko odczyt stanu i listy źródeł")
    parser.add_argument("--source-id", help="UUID pojedynczego aktywnego źródła do importu")
    args = parser.parse_args(argv)
    try:
        return run(args.url, source_id=args.source_id, list_only=args.list)
    except (SmokeError, EOFError, KeyboardInterrupt) as exc:
        print(f"News RSS DEV: {exc or 'Przerwano'}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
