-- ============================================================
--  03_code_seed.sql — 공통코드 배포 시드 (업체별)
--
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 새 업체를 열 때 이 파일 하나로 공통코드를 깐다. 0000(플랫폼 표준) 도 이걸로 만든다
--    2) 맨 위 :co_cd 만 바꿔서 돌린다 — psql -v co_cd=0001 -f 03_code_seed.sql
--    3) 이미 있는 코드는 이름·정렬·사용여부를 맞추고 없는 코드만 넣는다 (재실행 안전)
--
--  명명 규칙 (2026-08-25 확정)
--    main_cd : UPPER_SNAKE. 코드 그룹 이름이며 화면·서버가 문자열로만 쓴다
--    sub_cd  : **업무 테이블에 저장되는 값 그대로**. 대소문자를 바꾸지 않는다
--              예) tbl_schedule_rule.nonwork_rule = 'keep' 이면 sub_cd 도 'keep'
--                  tbl_document.doc_kind = 'html' 이면 sub_cd 도 'html'
--              여기를 대문자로 바꾸면 라벨이 안 붙고 콤보가 빈 값이 된다
--    sys_yn  : 이 파일이 까는 코드는 전부 'Y'. 업체가 화면에서 추가한 것만 'N'
--
--  적용: psql -v co_cd=0000 -f 03_code_seed.sql
-- ============================================================

SET search_path TO sasshaccp;

\if :{?co_cd}
\else
\set co_cd '0000'
\endif

BEGIN;

CREATE TEMP TABLE tmp_code(
    main_cd varchar(20),
    sub_cd  varchar(20),
    code_nm varchar(100),
    sort_no int,
    ref1    varchar(100)
) ON COMMIT DROP;

INSERT INTO tmp_code(main_cd, sub_cd, code_nm, sort_no, ref1) VALUES
-- 문서 상태 — tbl_document.status
('DOC_STATUS',  '*',        '문서 상태',   0, NULL),
('DOC_STATUS',  'WRK',      '작성중',      1, NULL),
('DOC_STATUS',  'REQ',      '승인요청',    2, NULL),
('DOC_STATUS',  'REV',      '검토완료',    3, NULL),
('DOC_STATUS',  'APV',      '승인완료',    4, NULL),
('DOC_STATUS',  'RJT',      '반려',        5, NULL),

-- 결재 역할 — tbl_approval_line_step.role_cd
('APPR_ROLE',   '*',        '결재 역할',   0, NULL),
('APPR_ROLE',   'WRITE',    '작성',        1, NULL),
('APPR_ROLE',   'REVIEW',   '검토',        2, NULL),
('APPR_ROLE',   'APPROVE',  '승인',        3, NULL),

-- 결재 결과 — tbl_document_approval.result_cd
('APPR_RESULT', '*',        '결재 결과',   0, NULL),
('APPR_RESULT', 'W',        '대기',        1, NULL),
('APPR_RESULT', 'A',        '승인',        2, NULL),
('APPR_RESULT', 'R',        '반려',        3, NULL),

-- 결재 행위 — 화면 버튼·감사 이력 문구
('APPR_ACTION', '*',        '결재 행위',   0, NULL),
('APPR_ACTION', 'REQUEST',  '전송',        1, NULL),
('APPR_ACTION', 'CANCEL',   '전송취소',    2, NULL),
('APPR_ACTION', 'REVIEW',   '검토완료',    3, NULL),
('APPR_ACTION', 'APPROVE',  '승인',        4, NULL),
('APPR_ACTION', 'REJECT',   '반려',        5, NULL),
('APPR_ACTION', 'UNDO',     '결재취소',    6, NULL),

-- 작성주기 — tbl_schedule_rule.cycle_cd
('CYCLE_CD',    '*',        '작성주기',    0, NULL),
('CYCLE_CD',    'D',        '매일',        1, NULL),
('CYCLE_CD',    'W',        '매주',        2, NULL),
('CYCLE_CD',    'M',        '매월',        3, NULL),
('CYCLE_CD',    'Q',        '분기',        4, NULL),
('CYCLE_CD',    'H',        '반기',        5, NULL),
('CYCLE_CD',    'Y',        '매년',        6, NULL),
('CYCLE_CD',    'E',        '비정기',      7, NULL),

-- 비영업일 처리 — tbl_schedule_rule.nonwork_rule (소문자 저장)
('NONWORK_RULE', '*',       '비영업일 처리', 0, NULL),
('NONWORK_RULE', 'keep',    '그대로',      1, NULL),
('NONWORK_RULE', 'prev',    '이전 영업일', 2, NULL),
('NONWORK_RULE', 'next',    '다음 영업일', 3, NULL),

-- 판정(적합/부적합) — 기록 표 judge_cd
('JUDGE_PF',    '*',        '판정(적합/부적합)', 0, NULL),
('JUDGE_PF',    'P',        '적합',        1, NULL),
('JUDGE_PF',    'F',        '부적합',      2, NULL),

-- 예·아니오 — 지면 점검 항목 yn (소문자 저장)
('JUDGE_YN',    '*',        '예·아니오',   0, NULL),
('JUDGE_YN',    'y',        '예',          1, NULL),
('JUDGE_YN',    'n',        '아니오',      2, NULL),

-- 지면 입력유형 — tbl_*_ver_item.input_type (소문자 저장)
('HTML_INPUT_TY', '*',          'HTML입력유형', 0, NULL),
('HTML_INPUT_TY', 'radio',      '라디오',      1, NULL),
('HTML_INPUT_TY', 'radio-num',  '라디오 숫자', 2, NULL),
('HTML_INPUT_TY', 'radio-text', '라디오·문자', 3, NULL),
('HTML_INPUT_TY', 'num',        '숫자',        4, NULL),
('HTML_INPUT_TY', 'text',       '문자',        5, NULL),

-- 사용여부 — 화면 콤보 (소문자 저장)
('USE_YN',      '*',        '사용여부',    0, NULL),
('USE_YN',      'y',        '사용',        1, NULL),
('USE_YN',      'n',        '미사용',      2, NULL),

-- 시스템유무 — 양식 구분 콤보 (소문자 저장)
('SYS_YN',      '*',        '시스템유무',  0, NULL),
('SYS_YN',      'sys',      '시스템',      1, NULL),
('SYS_YN',      'usr',      '사용자',      2, NULL),

-- 양식구분 — 양식관리 목록 (소문자 저장)
('SRC_TY',      '*',        '양식구분',    0, NULL),
('SRC_TY',      'sys',      '시스템',      1, NULL),
('SRC_TY',      'usr',      '사용자',      2, NULL),

-- 양식타입 — tbl_template.doc_kind (소문자 저장)
('TMPL_TY',     '*',        '양식타입',    0, NULL),
('TMPL_TY',     'html',     'HTML',        1, NULL),
('TMPL_TY',     'hwp',      'HWP',         2, NULL),

-- 개선조치 상태 — tbl_corrective_action.status
('CA_STATUS',   '*',        '개선조치 상태', 0, NULL),
('CA_STATUS',   'OPEN',     '미조치',      1, NULL),
('CA_STATUS',   'ING',      '조치중',      2, NULL),
('CA_STATUS',   'DONE',     '완료',        3, NULL),

-- 양식 분류 — tbl_template.category_cd
('CATEGORY_CD', '*',        '양식 분류',   0, NULL),
('CATEGORY_CD', 'CCP',      '중요관리점',  1, NULL),
('CATEGORY_CD', 'PRP',      '선행요건',    2, NULL),
('CATEGORY_CD', 'LAW',      '법정대장',    9, NULL),
('CATEGORY_CD', 'AUTO',     '자동기록',   10, NULL),

-- 알림 유형 — tbl_notification.noti_type_cd
('NOTI_TYPE',   '*',         '알림 유형',      0, NULL),
('NOTI_TYPE',   'DOC_DUE',   '작성기한 임박',  1, NULL),
('NOTI_TYPE',   'DOC_LATE',  '문서 미작성',    2, NULL),
('NOTI_TYPE',   'APPROVAL',  '결재 요청',      3, NULL),
('NOTI_TYPE',   'REJECT',    '결재 반려',      4, NULL),
('NOTI_TYPE',   'CA_DUE',    '개선조치 기한',  5, NULL),
('NOTI_TYPE',   'TASK_DUE',  '작성예정 임박',  6, NULL),
('NOTI_TYPE',   'TASK_LATE', '작성기한 경과',  7, NULL),

-- 로그인 결과 — tbl_login_log.result_cd
('LOGIN_RESULT', '*',       '로그인 결과', 0, NULL),
('LOGIN_RESULT', 'S',       '성공',        1, NULL),
('LOGIN_RESULT', 'F',       '실패',        2, NULL),
('LOGIN_RESULT', 'L',       '잠금',        3, NULL),

-- 감사 행위 — tbl_audit_log.act_cd
('AUDIT_RESULT', '*',          '감사 행위',     0, NULL),
('AUDIT_RESULT', 'I',          '등록',          1, NULL),
('AUDIT_RESULT', 'U',          '수정',          2, NULL),
('AUDIT_RESULT', 'D',          '삭제',          3, NULL),
('AUDIT_RESULT', 'APV',        '승인',          4, NULL),
('AUDIT_RESULT', 'RJT',        '반려',          5, NULL),
('AUDIT_RESULT', 'JUDGE_MOD',  '판정 수동변경', 6, NULL),
('AUDIT_RESULT', 'CO_SWITCH',  '업체 전환',     7, NULL),

-- 감사 대상 — tbl_audit_log.tbl_nm (표 이름 그대로 저장). ref1 은 대응 화면코드
('AUDIT_TARGET', '*',                 '감사 대상 메뉴', 0, NULL),
('AUDIT_TARGET', 'tbl_document',      '문서함',        1, 'document-inbox'),
('AUDIT_TARGET', 'tbl_document_file', '문서 파일',     2, 'document-inbox'),
('AUDIT_TARGET', 'tbl_code',          '공통코드 관리', 3, 'common-code-management'),
('AUDIT_TARGET', 'tbl_menu',          '메뉴 관리',     4, 'menu-management'),
('AUDIT_TARGET', 'tbl_role',          '권한그룹 관리', 5, 'role-management'),
('AUDIT_TARGET', 'tbl_role_screen',   '화면 권한',     6, 'role-management'),
('AUDIT_TARGET', 'tbl_dept',          '부서 관리',     7, 'department-management'),
('AUDIT_TARGET', 'tbl_user',          '사용자 관리',   8, 'user-management');

-- 없으면 넣고, 있으면 이름·정렬·사용여부를 시드에 맞춘다
INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, use_yn, ins_id, ins_dt)
SELECT :'co_cd', t.main_cd, t.sub_cd, t.code_nm, t.sort_no, t.ref1, 'Y', 'Y', 'system', now()
  FROM tmp_code t
ON CONFLICT ON CONSTRAINT ux_tbl_code DO UPDATE
   SET code_nm = EXCLUDED.code_nm,
       sort_no = EXCLUDED.sort_no,
       ref1    = EXCLUDED.ref1,
       sys_yn  = 'Y',
       use_yn  = 'Y',
       upd_id  = 'system',
       upd_dt  = now();

-- 시드에 없는 표준코드(sys_yn='Y')는 더 이상 쓰지 않는 것이므로 지운다.
-- 업체가 화면에서 추가한 코드(sys_yn='N')는 건드리지 않는다
DELETE FROM tbl_code c
 WHERE c.co_cd = :'co_cd'
   AND c.sys_yn = 'Y'
   AND NOT EXISTS (
       SELECT 1 FROM tmp_code t
        WHERE t.main_cd = c.main_cd AND t.sub_cd = c.sub_cd
   );

COMMIT;

-- 확인용
-- SELECT main_cd, count(*) FROM tbl_code WHERE co_cd = '0000' GROUP BY 1 ORDER BY 1;
-- SELECT count(*) FROM tbl_code WHERE co_cd = '0000' AND sys_yn <> 'Y';   -- 업체 추가분만
