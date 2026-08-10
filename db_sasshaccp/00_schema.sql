-- ============================================================
--  HACCP SaaS — 스키마 부트스트랩
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) sasshaccp DB 안에 sasshaccp 스키마를 생성하고 search_path를 고정한다
--    2) apply-all.sh 가 가장 먼저 실행하는 파일 — 이후 모든 DDL/SP가 이 스키마에 적재된다
--    3) DB 자체(CREATE DATABASE sasshaccp)는 apply-all.sh 가 postgres DB에 접속해 선행 생성한다
--
--  명명 규약 (metis 레거시와 다름 — 신규 정본)
--    테이블  : tbl_{의미}            (lower_snake, tbl_ 접두)
--    PK      : idx bigint GENERATED ALWAYS AS IDENTITY  (전 테이블 단일 대리키)
--    업무키  : UNIQUE 제약 ux_{테이블}_{키}             (복합 PK 대신 유니크로 관리)
--    테넌트  : co_cd varchar(10)     (UNIQUE 키 선두 구성요소 — JWT LoginUser.coCd 와 1:1)
--    감사    : ins_id / ins_dt / upd_id / upd_dt
--    SP      : sp_tbl_{명칭}_{r|c|d|u}_{000}
-- ============================================================

CREATE SCHEMA IF NOT EXISTS sasshaccp;

-- DB 기본 search_path 고정 — 새로 맺는 모든 세션에 적용된다
-- SP 본문은 테이블을 스키마 없이 참조하므로, 호출 세션의 search_path에 sasshaccp가 없으면
-- "relation ... does not exist" 로 실패한다. JDBC currentSchema 파라미터에만 의존하지 않도록
-- DB 레벨에서 한 번 더 못박아 둔다 (기존 세션에는 반영되지 않고 재접속부터 적용)
ALTER DATABASE sasshaccp SET search_path TO sasshaccp, public;

-- 이 파일 이후 같은 세션에서 실행되는 DDL/SP가 별도 지정 없이 이 스키마에 생성되도록 고정
SET search_path TO sasshaccp, public;

COMMENT ON SCHEMA sasshaccp IS '식육포장처리업 HACCP 기록·결재·보관 SaaS 전용 스키마';
