# ---------- Estagio 1: build -- instala as dependencias num venv ----------
FROM python:3.12-alpine AS build

WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && find /opt/venv -name "__pycache__" -type d -prune -exec rm -rf {} + \
    && pip uninstall -y pip

# ---------- Estagio 2: final -- so o venv + o codigo da aplicacao ----------
FROM python:3.12-alpine

# Atualiza pacotes do SO (corrige CVEs da base), remove o pip
# global (nao e usado em execucao) e cria um usuario sem privilegios.
RUN apk upgrade --no-cache \
    && python -m pip uninstall -y pip \
    && addgroup -S app && adduser -S -G app -h /app app \
    && mkdir -p /dados && chown app:app /dados

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SQLITE_PATH=/dados/loja.db

WORKDIR /app
COPY --from=build /opt/venv /opt/venv
COPY app/ ./app/
COPY static/ ./static/

USER app
EXPOSE 8000

# Roda dentro do container: alpine nao tem curl, entao usamos o Python
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"

# Forma exec: uvicorn e o PID 1 e recebe o SIGTERM do docker stop
CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
