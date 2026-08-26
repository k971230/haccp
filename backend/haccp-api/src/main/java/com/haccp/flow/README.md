# com.haccp.flow — 문서 흐름

FE `pages/flow` 와 같은 칸이다. 작성이 끝난 문서의 결재·보관·이탈조치를 맡는다.

| 하위 | 역할 |
|---|---|
| [`ca/`](ca/README.md) | 이탈·개선조치 — 문서에 딸린 개선조치 upsert·조회 |

결재 자체(상신·승인·반려·취소)는 문서 허브 `com.haccp.docs.documents` 가 갖는다.
여기는 결재에 딸린 부수 도메인만 둔다.
