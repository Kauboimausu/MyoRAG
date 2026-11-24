#!/usr/bin/env bash
# Manda cada PDF de data/raw/pdf/ a GROBID y guarda el TEI crudo en data/raw/tei/<id>.tei.xml.
#
# Requiere GROBID corriendo:
#   podman run --rm --init --ulimit core=0 -p 8070:8070 docker.io/grobid/grobid:0.9.0-crf
#
# Uso:
#   scripts/grobid_batch.sh            # procesa solo los que no tienen TEI
#   scripts/grobid_batch.sh --force    # vuelve a procesar todos
#
# Documentación de la API: https://grobid.readthedocs.io/en/latest/Grobid-service/

set -euo pipefail

GROBID_URL="${GROBID_URL:-http://localhost:8070}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDF_DIR="$ROOT/data/raw/pdf"
TEI_DIR="$ROOT/data/raw/tei"

force=0
[[ "${1:-}" == "--force" ]] && force=1

if ! curl -sf -m 5 "$GROBID_URL/api/isalive" >/dev/null; then
    echo "GROBID no responde en $GROBID_URL. ¿Está corriendo el contenedor?" >&2
    exit 1
fi

mkdir -p "$TEI_DIR"

ok=0
skipped=0
failed=()

for pdf in "$PDF_DIR"/*.pdf; do
    id="$(basename "$pdf" .pdf)"
    out="$TEI_DIR/$id.tei.xml"

    if [[ -s "$out" && $force -eq 0 ]]; then
        skipped=$((skipped + 1))
        continue
    fi

    printf '%-22s ' "$id"
    start=$SECONDS
    tmp="$(mktemp "$TEI_DIR/.$id.XXXXXX")"

    # 503 = GROBID ocupado; se reintenta un par de veces.
    code=""
    for attempt in 1 2 3; do
        code="$(curl -s -m 300 -o "$tmp" -w '%{http_code}' \
            --form "input=@$pdf" \
            "$GROBID_URL/api/processFulltextDocument")" || code="curl_error"
        [[ "$code" != "503" ]] && break
        sleep $((attempt * 5))
    done

    # 200 con cuerpo vacío o 204 (sin contenido) también cuentan como fallo.
    if [[ "$code" == "200" && -s "$tmp" ]]; then
        mv "$tmp" "$out"
        ok=$((ok + 1))
        echo "ok ($((SECONDS - start)) s)"
    else
        rm -f "$tmp"
        failed+=("$id ($code)")
        echo "FALLÓ: $code"
    fi
done

echo
echo "Procesados: $ok  Saltados (ya existían): $skipped  Fallidos: ${#failed[@]}"
if (( ${#failed[@]} > 0 )); then
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
