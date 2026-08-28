# hwp — 사용양식 관리 (`hwp-template-management`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../README.md).

업체가 쓰는 **HWP 양식 목록**을 다룬다. 시스템 제공본과 자사 등록본을 한 표에서 보고,
자사 양식은 등록·파일 업로드·되돌리기·삭제까지 여기서 한다.

## 파일

| 파일 | 책임 |
|---|---|
| `HwpTemplateManagementPage.tsx` | 렌더·상태·API·rhwp 미리보기. 좌 목록 50 · 우 미리보기 50 |
| `HwpTemplateManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · `USR_TMPL_PREFIX` · `LIST_GRID_RULES` · `buildListColumns` · `buildButtonState` |
| `HwpTemplateFileHistModal.tsx` | 파일 이력 팝업 — 예전 버전을 골라 되돌린다 |

## 검색

| 조건 | 어디서 거르나 | 비우면 |
|---|---|---|
| 양식코드 | SP `LIKE` | 전체 |
| 양식명 | SP `LIKE` | 전체 |
| **구분** (`sys` 시스템제공 / `usr` 자사) | SP 가 값으로 | 전체 |
| **사용여부** (`Y` / `N`) | SP 가 값으로 | 전체 |

넷 다 서버가 거른다. 화면에서 걸러 내면 미사용 양식이 목록에 안 실려 손을 못 댄다.

**사용여부 기본값을 `Y` 로 두지 않는다.** 이 화면은 **미사용 양식을 다시 쓰게 만드는 곳**이라
안 보이면 되살릴 방법이 없다. 다른 화면(문서주기 등)이 기본 `Y` 인 것과 다르다.

구분·사용여부 목록은 공통코드 `SYS_YN`·`USE_YN` 에서 읽는다 — 화면이 라벨을 만들지 않는다.

## API · SP · 표

| 동작 | API (`api/docs/hwpTemplateApi.ts`) | SP | 표 |
|---|---|---|---|
| 목록 | `listHwpTemplates` | `sp_hwp_template_management_r_000` | `tbl_company_template` · `tbl_template` |
| 저장 | `saveHwpTemplate` | `sp_hwp_template_management_c_000` | 위 |
| 삭제 | `validateDeleteCompanyTemplates` → `deleteCompanyTemplates` | `sp_hwp_template_management_d_000` | 위 |
| 파일 이력 | `listHwpTemplateFiles` · `applyHwpTemplateFile` | `sp_hwp_template_management_file_*` | `tbl_company_template_file` |

**목록 SP 는 `t.doc_kind = 'HWP'` 로 고른다.** 양식코드를 정규식으로 나열하지 않는다 —
예전에 `hwp_sys_001~027` 로 박아 두어 `028` 부터가 목록에서 사라진 적이 있다.

## 손대면 안 되는 것

- **`sys_yn` 은 수정 대상이 아니다.** 양식 구분은 만든 뒤 못 바꾼다. 서버가 신규를 `usr` 로 강제한다
- **시스템 제공 양식은 못 지운다.** 화면이 버튼을 막고 SP 가 다시 막는다 (E2E 가 API 직접 호출까지 본다)
- 파일은 덮어쓰지 않는다 — `tbl_company_template_file` 에 쌓고 `current_file_idx` 로 가리킨다

## pref 키

`scrnCd = hwp-template-management` · `persistId` 는 `HwpTemplateManagementRule.ts` 의 상수다 — **값 변경 금지.**

## 관련

- 표 레이아웃: [`docs/10_테이블_레이아웃.md`](../../../../../docs/10_테이블_레이아웃.md)
- SP → 표: [`docs/9_SP_색인.md`](../../../../../docs/9_SP_색인.md)
- E2E: `e2e/docs-hwp-template.spec.ts`
