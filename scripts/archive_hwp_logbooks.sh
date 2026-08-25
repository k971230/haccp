#!/usr/bin/env bash
# archive_hwp_logbooks.sh — HWP 작성 문서 파일을 _legacy 로 옮긴다 (삭제 아님)
#
# 개발자: 박승우
# 일자: 2026-08-25
# 코멘트:
#   1) 126 SQL 이 DB 행만 지운 뒤 볼륨에 남는 HaccpLogBooks 를 보존 폴더로 옮긴다
#   2) 즉시 rm 하지 않는다. 6개월 후 최종 삭제는 별도 지시
#   3) 확인 쿼리 표를 보고 승인한 뒤에만 실행한다
#
# 로컬:
#   SRC=backend/haccp-api/data/haccp-files/HaccpLogBooks DEST=backend/haccp-api/data/haccp-files/_legacy/HaccpLogBooks bash scripts/archive_hwp_logbooks.sh
# 운영:
#   SRC=/var/haccp/files/HaccpLogBooks DEST=/var/haccp/files/_legacy/HaccpLogBooks bash scripts/archive_hwp_logbooks.sh
#
set -euo pipefail

SRC="${SRC:-}"
DEST="${DEST:-}"
STAMP="$(date +%Y%m%d)"

if [[ -z "$SRC" || -z "$DEST" ]]; then
  echo "SRC 와 DEST 를 지정하세요. 예: SRC=/var/haccp/files/HaccpLogBooks DEST=/var/haccp/files/_legacy/HaccpLogBooks" >&2
  exit 1
fi

if [[ ! -d "$SRC" ]]; then
  echo "원본 폴더가 없습니다: $SRC (옮길 파일 없음)"
  exit 0
fi

TARGET="$DEST/$STAMP"
mkdir -p "$TARGET"

# 폴더 안 항목만 옮긴다. SRC 자체는 남겨 새 작성이 같은 경로를 쓰게 한다
shopt -s dotglob nullglob
moved=0
for item in "$SRC"/*; do
  mv "$item" "$TARGET/"
  moved=$((moved + 1))
done

echo "옮긴 항목 ${moved} 개 → $TARGET"
echo "6개월 후 최종 삭제는 이 폴더를 지운다. 자동 크론은 없다."
