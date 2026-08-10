#!/usr/bin/env bash
# ============================================================
#  HACCP SaaS — PostgreSQL 일괄 적용
#
#  개발자: 박승우
#  일자: 2026-08-05
#  코멘트:
#    1) DB(sasshaccp) 생성 → 스키마 → DDL → 인덱스 → 시드 → 저장프로시저 순으로 적용
#    2) 전 파일이 IF NOT EXISTS / ON CONFLICT 기반이라 몇 번을 다시 돌려도 결과가 같다
#    3) 접속정보는 환경변수로만 주입한다 — 비밀번호를 인자나 파일에 적지 말 것
#
#  사용:
#    PGHOST=호스트 PGPORT=5432 PGUSER=계정 PGPASSWORD=*** bash apply-all.sh
#
#  psql이 로컬에 없으면 도커로 대체 실행:
#    PSQL="docker run --rm -i -e PGPASSWORD -v $PWD:/sql postgres:16 psql" 처럼
#    PSQL 환경변수를 지정하되, -f 경로가 컨테이너 기준이어야 하므로 apply-all-docker.sh 사용을 권장
#
#  psql·도커 둘 다 없는 개발 PC(현재 작업 환경)에서는 JDBC 적용기를 쓴다 — 결과는 동일하다:
#    javac -encoding UTF-8 -d tools/out tools/ApplyHaccpDb.java
#    PGHOST=... PGPASSWORD=*** java -cp 'tools\out;<postgresql-42.7.4.jar>' ApplyHaccpDb db_sasshaccp
# ============================================================
set -euo pipefail
export PGCLIENTENCODING=UTF8

DIR="$(cd "$(dirname "$0")" && pwd)"
PSQL="${PSQL:-psql}"
DBNAME="${PGDATABASE:-sasshaccp}"

# DB가 없으면 만든다 — CREATE DATABASE는 트랜잭션 안에서 실행할 수 없어 postgres DB에 붙어 별도 실행
echo ">>> ensure database: $DBNAME"
if ! "$PSQL" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DBNAME'" | grep -q 1; then
  "$PSQL" -d postgres -c "CREATE DATABASE $DBNAME ENCODING 'UTF8'"
  echo "    created."
else
  echo "    already exists."
fi

run() { echo ">>> $1"; "$PSQL" -d "$DBNAME" -v ON_ERROR_STOP=1 -q -f "$DIR/$1"; }

run 00_schema.sql            # 스키마 생성 + search_path 고정
run 01_ddl_auth.sql          # 인증·플랫폼 10테이블
run 02_ddl_log.sql           # 로그·통계 4테이블
run 03_ddl_doc.sql           # 문서관리 허브 18테이블
run 04_ddl_master.sql        # 기준정보 9테이블
run 05_ddl_biz_ccp.sql       # 업무 - 중요관리점·검증
run 06_ddl_biz_hyg.sql       # 업무 - 위생관리
run 07_ddl_biz_ops.sql       # 업무 - 시설·재고·공정
run 08_indexes.sql           # 인덱스
run 09_seed_platform.sql     # 시드 - 템플릿 카탈로그·화면·공통코드
run 10_seed_check_item.sql   # 시드 - 표준 점검항목

# 시드 이후 마이그레이션·저장프로시저 — 파일명 번호 순(ApplyHaccpDb와 동일)
# 11_sp_* ~ 16_sp_* · 17_migrate_* · 18_sp_workflow ~ 22_sp_task_notification
for f in $(ls -v "$DIR"/*.sql); do
  base="$(basename "$f")"
  # 앞 두 자리가 숫자인 파일만 대상으로 한다
  num="${base%%_*}"
  # 00~10은 위에서 이미 적용했으므로 건너뛴다
  case "$num" in
    00|01|02|03|04|05|06|07|08|09|10) continue ;;
  esac
  run "$base"
done

echo "전체 적용 완료 — $DBNAME"
