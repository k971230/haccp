#!/usr/bin/env bash
# ============================================================
#  backup_export.sh — 백업을 호스트 밖으로 빼고, 오래된 것을 지운다
#
#  개발자: 박승우
#  일자: 2026-08-27
#  코멘트:
#    1) 덤프가 haccp-db-backup 볼륨, 즉 **같은 호스트 안**에만 쌓여 있었다 —
#       호스트가 통째로 죽으면 백업도 같이 죽는다
#    2) 지우는 것도 없어 무한히 쌓였다. 디스크가 차면 배포가 멈춘다
#    3) DB 덤프와 파일 tar 를 **짝으로** 뺀다. 하나만 있으면 복구가 반쪽이다
#
#  쓰기
#    bash scripts/backup_export.sh /mnt/backup            로컬 경로로 뺀다
#    bash scripts/backup_export.sh user@host:/srv/backup  scp 로 원격에 보낸다
#
#    KEEP_DAYS=14 bash scripts/backup_export.sh /mnt/backup   보관 일수 (기본 14)
#    DRY_RUN=1    bash scripts/backup_export.sh /mnt/backup   지우지 않고 보여만 준다
#
#  cron 예 — 매일 03:10
#    10 3 * * * cd /opt/haccp && \
#      docker compose --profile backup run --rm backup && \
#      docker compose --profile backup run --rm backup-files && \
#      bash scripts/backup_export.sh /mnt/backup >> /var/log/haccp-backup.log 2>&1
# ============================================================
set -euo pipefail

DEST="${1:?usage: backup_export.sh <대상경로 | user@host:/경로>}"
KEEP_DAYS="${KEEP_DAYS:-14}"
VOLUME="${BACKUP_VOLUME:-haccp-db-backup}"

# Git Bash 가 컨테이너 경로를 Windows 경로로 바꾸는 것을 막는다
export MSYS_NO_PATHCONV=1

docker volume inspect "$VOLUME" >/dev/null 2>&1 || {
  echo "백업 볼륨이 없다: $VOLUME"
  echo "먼저 떠야 한다 — docker compose --profile backup run --rm backup"
  exit 1
}

in_vol() { docker run --rm -v "$VOLUME:/b" busybox:1.36 "$@"; }

# ------------------------------------------------------------
# 1) 가장 최근 짝을 고른다 — DB 덤프 하나, 파일 tar 하나
# ------------------------------------------------------------
LATEST_DB="$(in_vol sh -c 'ls -1t /b/sasshaccp_*.dump 2>/dev/null | head -1' | tr -d '\r')"
LATEST_FILES="$(in_vol sh -c 'ls -1t /b/haccp-files_*.tar.gz 2>/dev/null | head -1' | tr -d '\r')"

[ -n "$LATEST_DB" ] || { echo "DB 덤프가 없다 — backup 프로파일을 먼저 돌린다"; exit 1; }
if [ -z "$LATEST_FILES" ]; then
  # 파일 백업이 없으면 복구가 반쪽이다. 멈추지는 않되 분명히 알린다
  echo "!! 파일 tar 가 없다 — DB 만 빼면 문서 첨부는 복구되지 않는다"
  echo "   docker compose --profile backup run --rm backup-files"
fi

echo ">>> 뺄 것"
echo "    DB   $LATEST_DB"
echo "    파일 ${LATEST_FILES:-(없음)}"

# ------------------------------------------------------------
# 2) 밖으로 뺀다 — 원격이면 scp, 아니면 복사
# ------------------------------------------------------------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
# 도커 마운트에는 Windows 경로(C:/...)가 필요하다 — Git Bash 는 /tmp/... 를 준다.
# pwd -W 가 있으면 그걸 쓴다 (MSYS 전용). 리눅스에서는 그대로다.
STAGE_MOUNT="$(cd "$STAGE" && { pwd -W 2>/dev/null || pwd; })"

copy_out() {
  local src="$1"
  local name
  name="$(basename "$src")"
  docker run --rm -v "$VOLUME:/b" -v "$STAGE_MOUNT:/out" busybox:1.36 cp "$src" "/out/$name"
  if [[ "$DEST" == *:* && "$DEST" != /* && "$DEST" != [A-Za-z]:* ]]; then
    scp -q "$STAGE/$name" "$DEST/"
  else
    mkdir -p "$DEST"
    cp "$STAGE/$name" "$DEST/"
  fi
  echo "    -> $DEST/$name"
}

echo ">>> 내보낸다"
copy_out "$LATEST_DB"
[ -n "$LATEST_FILES" ] && copy_out "$LATEST_FILES"

# ------------------------------------------------------------
# 3) 볼륨 안의 오래된 것을 지운다 — 안 지우면 디스크가 찬다
#    방금 뺀 것은 남긴다(-mtime 이 그날 것을 안 잡는다)
# ------------------------------------------------------------
echo ">>> ${KEEP_DAYS}일보다 오래된 것을 지운다"
OLD="$(in_vol sh -c "find /b -maxdepth 1 -type f \\( -name 'sasshaccp_*.dump' -o -name 'haccp-files_*.tar.gz' \\) -mtime +${KEEP_DAYS} -print" | tr -d '\r')"

if [ -z "$OLD" ]; then
  echo "    지울 것 없음"
elif [ "${DRY_RUN:-0}" = "1" ]; then
  echo "$OLD" | sed 's/^/    (지울 예정) /'
else
  echo "$OLD" | sed 's/^/    지움 /'
  in_vol sh -c "find /b -maxdepth 1 -type f \\( -name 'sasshaccp_*.dump' -o -name 'haccp-files_*.tar.gz' \\) -mtime +${KEEP_DAYS} -delete"
fi

echo ">>> 볼륨에 남은 것"
in_vol sh -c 'ls -1t /b 2>/dev/null | head -10' | sed 's/^/    /'

cat <<'MSG'

>>> 뺐다고 끝이 아니다 — **되돌려 봐야** 백업이다.
    분기에 한 번은 시험용 DB 에 복구해 본다.

      RESTORE_CONFIRM=sasshaccp_test bash scripts/db_restore.sh <덤프> sasshaccp_test
MSG
