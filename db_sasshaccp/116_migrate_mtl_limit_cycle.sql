-- ============================================================
-- 116 — 금속검출 한계기준 1행 · 주기 4줄
--
-- 파일번호: 116
-- 이전번호: 115
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 한계기준은 금속이물 1행. limit-run 은 지면에서 빼고 주기 문구로 합친다
--   2) 주기는 정상작동 확인·작업전중후·공정품 확인·작업 중 상시 4줄. 수정 가능
--   3) 113 재실행 금지. 옛 기본 주기 문구만 자사 본도 맞춘다
--
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- 예시 시드 — 주기 4줄
UPDATE tbl_check_item
   SET item_nm = $y$금속검출기 정상작동 여부 확인
작업시작 전, 작업 중 2시간마다, 작업 종료 후
금속검출기에 의한 공정품 확인
작업 중 상시$y$,
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'tml_ccp_mtl_000'
   AND item_cd = 'cycle';

-- 정상작동 한계 행 — 주기에 합쳤으므로 시드에서 숨김
UPDATE tbl_check_item
   SET use_yn = 'N',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'tml_ccp_mtl_000'
   AND item_cd = 'limit-run';

-- 자사 본 — 옛 기본 주기만 4줄로. 사용자가 고친 문구는 그대로
UPDATE tbl_tml_ccp_mtl_ver_item
   SET item_nm = $y$금속검출기 정상작동 여부 확인
작업시작 전, 작업 중 2시간마다, 작업 종료 후
금속검출기에 의한 공정품 확인
작업 중 상시$y$,
       upd_id = 'system',
       upd_dt = now()
 WHERE item_cd = 'cycle'
   AND item_nm = $o$작업시작 전, 작업 중 2시간마다, 작업 종료 후
금속검출기에 의한 공정품 확인, 작업 중 상시$o$;
