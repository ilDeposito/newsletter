#!/usr/bin/env bash
# Wrapper listmonk: up / stop / restart / pull (+ logs, status).
# up e restart ricreano il container listmonk per applicare i template
# custom in ops/listmonk-static (mount + --static-dir, vedi docker-compose.yml).
set -euo pipefail

cd "$(dirname "$0")"

SERVICE="listmonk"
TEMPLATE_FILE="ops/listmonk-static/email-templates/base.html"
COMPOSE_FILE="docker-compose.yml"

die() { echo "ERRORE: $*" >&2; exit 1; }

check_compose() {
  command -v docker >/dev/null 2>&1 || die "docker non trovato in PATH"
  [[ -f "$COMPOSE_FILE" ]] || die "$COMPOSE_FILE non trovato"
  [[ -f .env ]] || die "file .env mancante (copia da .env.example e compilalo)"
}

# Verifica pre-volo: template presente e override cablato nel compose.
check_templates() {
  [[ -f "$TEMPLATE_FILE" ]] || die "$TEMPLATE_FILE non trovato"
  grep -q "static-override" "$COMPOSE_FILE" || die "mount static-override mancante in $COMPOSE_FILE"
  grep -q "\-\-static-dir" "$COMPOSE_FILE" || die "flag --static-dir mancante in $COMPOSE_FILE"
}

# Ricrea listmonk così rilegge --static-dir e verifica mount + errori template.
apply_templates() {
  echo "==> Applico template: recreate $SERVICE..."
  docker compose up -d --force-recreate "$SERVICE"
  echo "==> Verifica mount static-override..."
  docker inspect ildeposito_listmonk \
    --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' \
    | grep -q "static-override" \
    || die "mount /listmonk/static-override non attivo (controlla volumes in $COMPOSE_FILE)"
  echo "==> Log recenti (errori template/static):"
  docker compose logs --tail=30 "$SERVICE" | grep -iE "template|static|error|panic" || echo "(nessun errore template nei log recenti)"
  echo "OK: template applicati. Se hai appena modificato base.html, fai un invio di test."
}

cmd_up() {
  check_compose
  check_templates
  echo "==> docker compose up -d ..."
  docker compose up -d
  apply_templates
}

cmd_restart() {
  check_compose
  check_templates
  echo "==> restart con recreate per applicare i template..."
  apply_templates
}

cmd_stop() {
  check_compose
  docker compose stop
}

cmd_pull() {
  check_compose
  docker compose pull
}

cmd_logs() {
  check_compose
  docker compose logs -f "$SERVICE"
}

cmd_status() {
  check_compose
  docker compose ps
}

usage() {
  cat <<'EOF'
Uso: ./listmonk.sh {up|stop|restart|pull|logs|status|help}

  up       compose up -d (tutti i servizi) + recreate listmonk per applicare i template
  restart  recreate listmonk per applicare i template (senza toccare il db)
  stop     compose stop (mantiene volumi e rete)
  pull     compose pull (aggiorna le immagini, non riavvia)
  logs     tail log del servizio listmonk
  status   compose ps
EOF
}

case "${1:-help}" in
  up) cmd_up ;;
  restart) cmd_restart ;;
  stop) cmd_stop ;;
  pull) cmd_pull ;;
  logs) cmd_logs ;;
  status) cmd_status ;;
  help|-h|--help) usage ;;
  *) die "comando sconosciuto: $1 (usa: up|stop|restart|pull|logs|status|help)" ;;
esac
