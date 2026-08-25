# dto — 양식 작성 공용 DTO

HYG·CCP검증·CCP 모니터링 **5화면이 같은 모양**을 쓴다. 화면별 dto 로 복제하지 않는다
(규칙 08 「공유 유틸은 영역 루트에 둔다」).

| DTO | 역할 | FE 대응 타입 |
|---|---|---|
| `DraftFormRow` | 양식 선택 팝업 목록 (사용여부 예) | `HtmlFormDraftForm` |
| `DraftListRow` | 좌측 작성 목록 | `HtmlFormDraftListRow` |
| `DraftSaveRequest` | 저장 본문 | `HtmlFormDraftSaveRequest` |
| `DraftDeleteItem` | 삭제 키 `[{ docIdx }]` | — |
| `DraftLogRow` | 기록 표 1행 (`phaseCd`·`cells`) | `HtmlFormLogRow` |
| `DraftPassRow` | 금속 통과량 표 1행 | `HtmlFormPassRow` |

FE 타입은 `frontend/haccp-web/src/api/draft/htmlFormDraftTypes.ts` 와
`components/form/htmlFormPaperShared.tsx` 에 있다. **한쪽만 필드를 늘리면 조용히 누락**되므로
양쪽을 같이 고친다.

## 화면별로 쓰는 본문 배열

| 화면 | items | logRows | passRows |
|---|---|---|---|
| `hyg-process` · `ccp-verify` | O | — | — |
| `ccp-pkg` · `ccp-htg` | — | O | — |
| `ccp-mtl` | — | O (감도) | O (통과량) |

안 쓰는 배열은 `null` 로 온다. 서비스가 자기 것만 읽는다.
