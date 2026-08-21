# 문서함 · 결재함 · 결재이력 (`document-inbox` · `approval-inbox` · `approval-history`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../README.md).

세 화면이 `DocumentBoxPage` 하나를 `mode`로 나눈다. 복제하지 않는다.

## 파일

| 파일 | 책임 |
|---|---|
| `DocumentBoxPage.tsx` | 렌더·상태·API. 좌 목록 + 우 상세·결재 |
| `DocumentBoxRule.ts` | `scrnCdOf` · `listPersistIdOf` · 컬럼 · `DOC_KIND_OPTIONS` |

## 화면 규칙

- inbox: 작성 문서. 타입(DB/한글) FE 필터
- approval: 내 차례만. 작성·삭제 숨김
- history: 내가 처리한 결재

## pref 키

`document-inbox` → `doc-document-inbox` · `approval-inbox` → `doc-approval-inbox` · `approval-history` → `doc-approval-history` · 상세 결재이력 `doc-box-approval-history`
