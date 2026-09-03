# 문서함 · 결재 대기 · 결재 완료 (`document-inbox` · `sign-ready` · `sign-ok`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../../../docs/README.md).

세 화면이 `DocumentBoxPage` 하나를 `mode`로 나눈다. 복제하지 않는다.

## 파일

| 파일 | 책임 |
|---|---|
| `DocumentBoxPage.tsx` | 렌더·상태·API. 좌 목록 + 우 상세·결재. 좌우 `ResizableSplit` |
| `DocumentBoxRule.ts` | `scrnCdOf` · `listPersistIdOf` · `splitKeyOf` · 컬럼 · `DOC_KIND_OPTIONS` · 결재 스테퍼 변환 |
| `DocumentBoxRule.test.ts` | 스테퍼 칸 색·단계 정렬 |

## 화면 규칙

- inbox(`document-inbox`): **결재까지 끝난 문서(APV)만** 모아 보는 보관함. 좌 목록 + 우 미리보기.
  **조회·인쇄만** — 신규·저장·삭제·첨부 등록·관련 문서를 두지 않는다.
  목록 체크박스로 고른 행을 인쇄한다. HTML 은 A4 지면을 한 번에, HWP 는 서버 PDF 변환 후 건별.
  결재완료 본문·사용자첨부는 안 바꾸고, PDF 완료본만 재사용하거나 새로 남긴다.
  타입(DB/한글) 필터만 남기고 상태 필터는 뺐다(항상 승인완료)
- approval(`sign-ready`): 내 차례만. 작성·삭제·인쇄 숨김. 문서 본문 미리보기 있음
- history(`sign-ok`): 내가 처리한 결재. 미리보기 + 결재취소(UNDO)

우측 미리보기는 기본 펼침(원본 전체). 접기 토글과 하단 드래그로 높이를 조절한다.
결재 단계는 그리드가 아니라 결재 첨부와 같은 가로 순서형 스테퍼다.
상태 배지는 제목(`h2`) 옆이다. `h2` 는 양식명(`tmplNm`)이다. 작성 목록 `title` 은 언제·무엇을 썼는지 식별용이라 지면에 안 넣는다. 승인·반려·취소 버튼은 그 오른쪽. 반려·취소 사유는 `ReasonAction` 팝업으로 받고, 값이 있으면 미리보기 아래에 읽기 전용 textarea 로 보여 준다.

결재 2화면의 업무 규칙은 [`pages/flow/appr/README.md`](../../appr/README.md) 가 정본이다.

## pref 키

`document-inbox` → `doc-document-inbox` · `sign-ready` → `doc-approval-inbox` · `sign-ok` → `doc-approval-history`

pref 키는 2026-08-25 화면코드 개명 때 **일부러 그대로 뒀다** — 바꾸면 저장된 열 너비가 초기화된다.

좌우 분할 키는 `haccp-split-{scrnCd}-50` (`splitKeyOf`). 이번에 처음 넣어서 화면코드를 그대로 쓴다.
