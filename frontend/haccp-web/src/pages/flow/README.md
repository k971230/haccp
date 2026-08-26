# pages/flow — 문서 현황·결재

URL `/flow`. 작성이 끝난 문서가 결재를 거쳐 보관되기까지의 화면 묶음이다.

```
작성(draft) → 전송 → 결재 첨부(attach) → 결재 대기(sign-ready) → 결재 완료(sign-ok)
                                                                     ↓ 승인
                                                            문서함(document-inbox)
이탈이 있으면 → 이탈·개선조치(corrective-action-management)
```

| 하위 | 중분류 | 화면 |
|---|---|---|
| [`appr/`](appr/README.md) | `appr` 결재 | `attach` · `sign-ready` · `sign-ok` |
| [`box/`](box/README.md) | `box` 문서함 | `document-inbox` |
| [`ca/`](ca/README.md) | `ca` 이탈·개선조치 | `corrective-action-management` |

문서 상태는 `DOC_STATUS` 하나로 흐른다 — `WRK` 작성중 → `REQ` 승인요청 → `APV` 승인완료 (·`RJT` 반려).
검토(`REV`)는 기본 결재선에서 꺼 두었다. 켜면 그대로 동작한다.
