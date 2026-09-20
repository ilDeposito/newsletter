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

## Template email di sistema

L'header/footer delle email transazionali (opt-in, disiscrizione, export, notifiche admin) è brandizzato via override del solo `base.html`:

```text
ops/listmonk-static/email-templates/base.html  # custom, montato nel container
ops/listmonk-static/UPSTREAM_VERSION            # versione upstream di riferimento (es. v6.2.0)
ops/reference/base.html.v6.2.0                  # copia pristine dell'upstream, per i diff (fuori dal mount)
```

Il mount `./ops/listmonk-static:/listmonk/static-override:ro` + flag `--static-dir` (vedi `docker-compose.yml`) fa **overlay**: solo `base.html` viene sovrascritto, tutto il resto resta quello embedded nell'immagine. Comandi rapidi in `listmonk.sh` (`up`, `stop`, `restart`, `pull`); dopo ogni modifica ai template: `./listmonk.sh restart`.

## Upgrade di Listmonk (con template custom)

NON fare mai solo `docker compose pull`: prima verifica se il nuovo `base.html` upstream è cambiato, altrimenti rischi di sovrascrivere / perdere coerenza col branding. Procedura:

1. Controlla il pin attuale:

   ```sh
   cat ops/listmonk-static/UPSTREAM_VERSION
   grep 'image: listmonk/listmonk' docker-compose.yml
   ```

2. Scarica lo static della nuova versione (sostituisci `X.Y.Z`):

   ```sh
   NEW=X.Y.Z
   mkdir -p /tmp/lm-$NEW && curl -sL https://github.com/knadh/listmonk/archive/refs/tags/v$NEW.tar.gz -o /tmp/lm-$NEW.tar.gz
   tar xzf /tmp/lm-$NEW.tar.gz -C /tmp/lm-$NEW
   ```

3. Diff upstream-vecchio vs upstream-nuovo (cosa ha cambiato listmonk):

   ```sh
   OLD=$(cat ops/listmonk-static/UPSTREAM_VERSION | tr -d v)
   diff -u ops/reference/base.html.v$OLD /tmp/lm-$NEW/listmonk-$NEW/static/email-templates/base.html || true
   ```

   - Nessuna differenza: vai allo step 5 (bump diretto).
   - Differenze: vai allo step 4 (rebase).

4. Rebase: parti dal **nuovo** `base.html` upstream e riapplica le personalizzazioni (logo centrato via `LogoURL`, scritta sito, divisori `#dddddd`, 4 icone social, rimozione `powered by`). Confronta il custom col nuovo upstream per guidarti:

   ```sh
   diff -u /tmp/lm-$NEW/listmonk-$NEW/static/email-templates/base.html ops/listmonk-static/email-templates/base.html || true
   ```

   Vincoli: non toccare `{{ define "header" }}` / `{{ define "footer" }}`, le espressioni Go `{{ ... }}` e la logica `{{ if ne LogoURL "" }}`.

5. Aggiorna pin, reference e immagine (sostituisci `X.Y.Z`):

   ```sh
   NEW=X.Y.Z
   cp /tmp/lm-$NEW/listmonk-$NEW/static/email-templates/base.html ops/reference/base.html.v$NEW
   rm ops/reference/base.html.v$(cat ops/listmonk-static/UPSTREAM_VERSION | tr -d v)
   echo "v$NEW" > ops/listmonk-static/UPSTREAM_VERSION
   ```

   poi in `docker-compose.yml` cambia il tag: `image: listmonk/listmonk:vX.Y.Z`.

6. Applica e verifica:

   ```sh
   ./listmonk.sh pull && ./listmonk.sh restart
   ./listmonk.sh logs
   ```

   Controlla nei log che non ci siano errori `template|static|error`, poi in UI fai `Settings > SMTP > Send test email` e un'iscrizione di prova con double opt-in.

Rollback: rimetti il vecchio tag in `docker-compose.yml`, ripristina `UPSTREAM_VERSION` + reference precedenti, `./listmonk.sh restart`.
