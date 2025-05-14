# 1) Rechte setzen
chown "$(whoami):$(whoami)" logs

# 2) Docker hochfahren
docker compose up -d

# 3) Logs automatisch ins Verzeichnis schreiben
#    --no-color entfernt ANSI‐Farbcodes
docker compose logs -f --no-color > logs/all-containers.log 2>&1 &

echo "🚀 Docker läuft – Logs in logs/all-containers.log"