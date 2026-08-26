# com.haccp.flow.ca — 이탈·개선조치

두 갈래를 맡는다. **섞지 않는다.**

| 갈래 | 무엇 | 파일 |
|---|---|---|
| 개선조치관리 **화면** | 독립 개선조치 목록·저장·삭제 | `CorrectiveActionController` · `Service` · `Mapper` |
| 문서에 딸린 개선조치 | 문서 하나에 0..1 건. 작성 화면이 저장할 때마다 맞춘다 | `DocCorrectiveSupport` · `DocCorrectiveMapper` |

| 파일 | 역할 |
|---|---|
| `CorrectiveActionController.java` | `/api/v1/flow/ca/corrective-action-management/*` — 목록·저장·삭제 |
| `CorrectiveActionService.java` | `sp_tbl_corrective_action_*` 업무 판단·JWT |
| `CorrectiveActionMapper.java` | XML `mapper/flow/ca/CorrectiveActionMapper.xml` |
| `DocCorrectiveSupport.java` | 양식 Service 들이 저장 직후 같은 계약으로 호출하는 헬퍼 |
| `DocCorrectiveMapper.java` | `sp_tbl_doc_corrective_*` 호출 |
| [`dto/`](dto/README.md) | `DocCorrectiveDto` — 이탈내용·조치내용·조치자·확인자 |

## 규칙

- `saveAutoIfNg(..., hasNg, ...)` — 부적합이 있는데 사용자가 안 적었으면 자동 문구로 행을 만든다
- **빈 payload 는 삭제다.** SP 가 이탈내용·조치내용이 모두 비면 행을 지운다.
  HWP 작성은 지면이 없어 payload 가 항상 비므로, 끄기 전에 기존 내용을 확인하고
  적혀 있으면 손대지 않는다 (`HwpDraftService.applyDeviation`)

## 변경

- 2026-08-26 — 개선조치관리 **화면 API 를 `tsk` 에서 여기로 옮겼다.**
  URL 은 `/api/v1/flow/ca/...` 인데 컨트롤러가 `com.haccp.tsk` 에 있어
  「URL = 폴더 = 패키지」 가 깨져 있었다
- 2026-08-25 — `DocCorrectiveDto` 를 `docs.ccp.dto` 에서 여기로 옮겼다 (CCP 패키지가 화면 정리로 사라졌다)
매퍼 XML `resultType` 도 같이 옮겨야 한다. **MyBatis 는 컴파일로 안 잡히고 기동에서 터진다.**
