# 문서함 · 결재 대기 · 결재 완료 (`document-inbox` · `sign-ready` · `sign-ok`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../../../docs/README.md).

세 화면이 `DocumentBoxPage` 하나를 `mode`로 나눈다. 복제하지 않는다.

## 파일

| 파일 | 책임 |
|---|---|
| `DocumentBoxPage.tsx` | 렌더·상태·API. 좌 목록 + 우 상세·결재 |
| `DocumentBoxRule.ts` | `scrnCdOf` · `listPersistIdOf` · 컬럼 · `DOC_KIND_OPTIONS` |

## 화면 규칙

- inbox(`document-inbox`): **결재까지 끝난 문서(APV)만** 모아 보는 보관함. 좌 목록 + 우 미리보기.
  **조회 전용이다** — 신규·저장·삭제·첨부 등록·관련 문서를 두지 않는다.
  타입(DB/한글) 필터만 남기고 상태 필터는 뺐다(항상 승인완료)
- approval(`sign-ready`): 내 차례만. 작성·삭제 숨김. 문서 본문 미리보기 있음
- history(`sign-ok`): 내가 처리한 결재. 미리보기 + 결재취소(UNDO)

결재 2화면의 업무 규칙은 [`pages/flow/appr/README.md`](../../appr/README.md) 가 정본이다.

## pref 키

`document-inbox` → `doc-document-inbox` · `sign-ready` → `doc-approval-inbox` · `sign-ok` → `doc-approval-history` · 상세 결재이력 `doc-box-approval-history`

pref 키는 2026-08-25 화면코드 개명 때 **일부러 그대로 뒀다** — 바꾸면 저장된 열 너비가 초기화된다.
