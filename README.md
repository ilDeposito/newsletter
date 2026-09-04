# Listmonk con Caddy

Questo stack usa [Listmonk](https://listmonk.app/) e PostgreSQL. Non espone porte sull'host: Caddy deve essere collegato alla rete Docker esterna `caddy` e usare il plugin `caddy-docker-proxy` (le label nel compose seguono la sua sintassi).

## Avvio

1. Crea la rete una sola volta, se non esiste:

   ```sh
   docker network create caddy
   ```

2. Crea e compila il file dei segreti:

   ```sh
   cp .env.example .env
   ```

3. Avvia lo stack:

   ```sh
   docker compose up -d
   ```

Apri `https://LISTMONK_DOMAIN`. I dati PostgreSQL e i media caricati sono conservati nei volumi Docker `listmonk_db` e `listmonk_uploads`. Per usare gli upload, imposta `/listmonk/uploads` in **Settings → Media** di Listmonk.

Per aggiornare l'immagine:

```sh
docker compose pull && docker compose up -d
```
