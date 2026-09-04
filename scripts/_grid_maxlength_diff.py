"""그리드 컬럼의 maxLength 가 DDL 폭과 같은지 대조한다.

개발자: 박승우
일자: 2026-09-04
코멘트:
  1) *Rule.ts 의 maxLength 를 00_ddl.sql 의 varchar(N) 과 맞춰 본다
  2) audit_grid_maxlength.sh 가 부른다 — 직접 부르지 않는다
  3) 어긋나거나, 저장 가능한 문자 칸에 상한이 없으면 종료코드 1

왜 있나: 화면의 상한과 표의 폭은 **같은 수여야 한다.** 폭을 좁히면서 화면을 안 고치면
22001 이 그대로 사용자에게 뜨고, 폭을 넓히면서 화면을 안 고치면 쓸 수 있는 칸이 좁아진다.
사람이 두 자리를 같이 기억하는 대신 여기서 대조한다.

짝은 아래 MAP 에 적는다. 화면과 표의 이름이 늘 같지는 않아서 기계로 못 짚는다.
"""
import io
import re
import sys

BASE = r'D:\haccp\frontend\haccp-web\src\pages'
DDL = r'D:\haccp\db_sasshaccp\00_ddl.sql'

# 화면 Rule 파일 → { 화면 필드: (표, 컬럼) }
# text 컬럼(deviationDesc·actionDesc)은 상한이 없어 넣지 않는다.
MAP = {
    r'\docs\hwp\HwpTemplateManagementRule.ts': {
        "tmplNm": ("tbl_company_template", "tmpl_nm_ovr"),
    },
    r'\flow\ca\corrective\CorrectiveActionManagementRule.ts': {
        "occurPlace": ("tbl_corrective_action", "occur_place"),
        "actionUserNm": ("tbl_corrective_action", "action_user_nm"),
    },
    r'\sys\code\approvalline\ApprovalLineManagementRule.ts': {
        "apprLineCd": ("tbl_approval_line", "appr_line_cd"),
        "apprLineNm": ("tbl_approval_line", "appr_line_nm"),
    },
    r'\sys\code\commoncode\CommonCodeRule.ts': {
        "subCd": ("tbl_code", "sub_cd"),
        "codeNm": ("tbl_code", "code_nm"),
        "ref1": ("tbl_code", "ref1"),
        "ref2": ("tbl_code", "ref2"),
    },
    r'\sys\code\department\DepartmentManagementRule.ts': {
        "deptCd": ("tbl_dept", "dept_cd"),
        "deptNm": ("tbl_dept", "dept_nm"),
    },
    r'\sys\code\menu\MenuManagementRule.ts': {
        "menuNm": ("tbl_menu", "menu_nm"),
    },
    r'\sys\code\role\RoleManagementRule.ts': {
        "usrgrpCd": ("tbl_role", "usrgrp_cd"),
        "usrgrpNm": ("tbl_role", "usrgrp_nm"),
        "descRmk": ("tbl_role", "desc_rmk"),
    },
    r'\sys\code\user\UserManagementRule.ts': {
        "userId": ("tbl_user", "user_id"),
        "userNm": ("tbl_user", "user_nm"),
        "email": ("tbl_user", "email"),
        "mobile": ("tbl_user", "mobile"),
    },
}

BLOCK = re.compile(r'\{[^{}]*?field:\s*"[a-zA-Z0-9_]+"[^{}]*?\}', re.S)


def ddl_widths():
    """표.컬럼 → varchar 폭. varchar 가 아닌 컬럼은 담지 않는다."""
    text = io.open(DDL, encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'CREATE TABLE sasshaccp\.(\w+) \((.*?)\n\);', text, re.S):
        table, body = m.group(1), m.group(2)
        for cm in re.finditer(r'^\s{4}(\w+)\s+character varying\((\d+)\)', body, re.M):
            out[(table, cm.group(1))] = int(cm.group(2))
    return out


def main():
    widths = ddl_widths()
    bad = 0
    for rel, fields in MAP.items():
        src = io.open(BASE + rel, encoding='utf-8').read()
        found = {}
        for m in BLOCK.finditer(src):
            block = m.group(0)
            fld = re.search(r'field:\s*"([a-zA-Z0-9_]+)"', block).group(1)
            if fld not in fields:
                continue
            hit = re.search(r'maxLength:\s*(\d+)', block)
            if hit:
                found[fld] = int(hit.group(1))
        for fld, (table, col) in fields.items():
            want = widths.get((table, col))
            if want is None:
                print(f"  {rel}: {fld} 의 짝 {table}.{col} 이 DDL 에 varchar 로 없다")
                bad += 1
                continue
            got = found.get(fld)
            if got is None:
                print(f"  {rel}: {fld} 에 maxLength 가 없다 ({table}.{col} = {want})")
                bad += 1
            elif got != want:
                print(f"  {rel}: {fld} maxLength {got} != {table}.{col} {want}")
                bad += 1
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
