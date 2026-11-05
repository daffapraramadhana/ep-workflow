#!/usr/bin/env bash
# Deploy satu service staging dari checkout CI, dengan health check + rollback.
#   deploy.sh api|web <path-checkout>
# Dipanggil oleh GitHub Actions (self-hosted runner) di ep-api / ep-web.
# Migrasi Prisma jalan saat container api boot — rollback image TIDAK
# membatalkan migrasi yang sudah terlanjur diterapkan.
#
# Salinan kanonik. Yang dieksekusi runner ada di /opt/english-app/infra/ci/
# pada host deploy; berkas ini sumbernya, supaya skrip yang menentukan cara
# produksi naik tidak hidup hanya di satu mesin.
set -euo pipefail

SERVICE=${1:?service: api|web}
CONTEXT=$(cd "${2:?path checkout}" && pwd)
INFRA=$(cd "$(dirname "$0")/.." && pwd)
COMPOSE=(docker compose -p samitago -f "$INFRA/docker-compose.staging.yml" --env-file "$INFRA/.env.staging")
IMAGE=samitago-$SERVICE

case $SERVICE in
  api) PORT=3101; HEALTH_PATH=/health; export API_BUILD_CONTEXT=$CONTEXT ;;
  web) PORT=3100; HEALTH_PATH=/;       export WEB_BUILD_CONTEXT=$CONTEXT ;;
  *) echo "service tak dikenal: $SERVICE" >&2; exit 2 ;;
esac
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-180}

healthy() {
  local deadline=$((SECONDS + HEALTH_TIMEOUT))
  until curl -fsS -o /dev/null "http://127.0.0.1:$PORT$HEALTH_PATH"; do
    (( SECONDS >= deadline )) && return 1
    sleep 3
  done
}

# Simpan image yang sedang jalan sebagai :prev SEBELUM build. Image store
# containerd membuang image yang kehilangan tag terakhirnya, jadi setelah
# build menggeser :latest, image lama tak bisa di-tag lagi dari container.
PREV_SAVED=
RUNNING=$("${COMPOSE[@]}" ps -q "$SERVICE" | head -1)
if [[ -n $RUNNING ]] && docker tag "$(docker inspect -f '{{.Image}}' "$RUNNING")" "$IMAGE:prev" 2>/dev/null; then
  PREV_SAVED=1
  echo "image berjalan disimpan sebagai $IMAGE:prev"
else
  echo "::warning::image berjalan tak bisa disimpan sebagai :prev — deploy ini tanpa rollback"
  docker rmi "$IMAGE:prev" >/dev/null 2>&1 || true   # jangan rollback ke :prev basi
fi

echo "::group::build $SERVICE @ $(git -C "$CONTEXT" rev-parse --short HEAD)"
"${COMPOSE[@]}" build "$SERVICE"
echo "::endgroup::"

# Tanpa :prev, image yang dirujuk container lama sudah lenyap dari image store
# begitu build menggeser :latest. `compose up` yang membandingkan container itu
# dengan image yang tiada gagal "No such image: sha256:…" dan menggugurkan
# deploy setelah build selesai — persis kegagalan deploy perdana api (run
# 41977039223). Di jalur ini rollback memang sudah tidak ada, jadi buang
# containernya lebih dulu dan biarkan compose membuatnya dari nol.
if [[ -z $PREV_SAVED ]]; then
  "${COMPOSE[@]}" rm -sf "$SERVICE" >/dev/null 2>&1 || true
fi

"${COMPOSE[@]}" up -d --no-deps --no-build "$SERVICE"

if healthy; then
  echo "✓ $SERVICE sehat di :$PORT$HEALTH_PATH"
  docker image prune -f >/dev/null
  exit 0
fi

echo "✗ $SERVICE tidak sehat dalam ${HEALTH_TIMEOUT}s — log terakhir:" >&2
"${COMPOSE[@]}" logs --tail 80 "$SERVICE" >&2 || true
if docker image inspect "$IMAGE:prev" >/dev/null 2>&1; then
  echo "↩ rollback ke $IMAGE:prev" >&2
  docker tag "$IMAGE:prev" "$IMAGE:latest"
  "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate "$SERVICE"
  healthy && echo "rollback sehat" >&2 || echo "ROLLBACK JUGA TIDAK SEHAT — cek manual" >&2
fi
exit 1
