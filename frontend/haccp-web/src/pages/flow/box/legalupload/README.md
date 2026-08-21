# 법적서류 (`legal-document-upload`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../../../docs/README.md).

## 파일

| 파일 | 책임 |
|---|---|
| `LegalDocumentUploadPage.tsx` | 렌더·상태·API. 좌 유형 + 우 등록 문서 |
| `LegalDocumentUploadRule.ts` | `SCRN_CD` · persistId · `TMPL_RULES`/`DOC_RULES` · 컬럼 팩터리 |

## 화면 규칙

- 시스템 유형(`sysYn=Y`)은 삭제 불가. 코드는 신규만
- 삭제는 `/api/v1/bas/company-templates/*` (사용양식과 URL 공유)
- 문서 I/O는 공용 `documentApi`

## pref 키

`scrnCd = legal-document-upload` · `legal-tmpl-list` · `legal-doc-list` — 값 변경 금지.
