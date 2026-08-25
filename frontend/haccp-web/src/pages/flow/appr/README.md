# pages/flow/appr — 결재 업무

URL `/flow/appr`. 문서 흐름의 결재 구간 3화면이다.

```
문서작성(draft) → 전송(REQUEST) → 결재 첨부(attach)
                                → 결재 대기(sign-ready) → 결재 완료(sign-ok)
```

| 화면코드 | URL | 대상 문서 | 이 화면에서 하는 일 |
|---|---|---|---|
| `attach` | `/flow/appr/attach` | 내가 작성한 문서 | 첨부 · 비고 · 진행상태 · **전송 / 전송취소** |
| `sign-ready` | `/flow/appr/sign-ready` | 내 차례인 문서 | 본문 확인 → **승인 / 취소 / 반려** |
| `sign-ok` | `/flow/appr/sign-ok` | 내가 처리한 문서 | 본문 확인 → **취소** (사유 선택) |

## 화면마다 버튼이 다른 이유

결재자는 문서를 고치지 않는다. 그래서 `sign-ready`·`sign-ok` 에는
**저장·작성화면·첨부 미리보기·관련 문서·상신취소를 두지 않는다**.
문서를 고치는 일은 작성 화면과 `attach` 의 몫이다.

검토·승인은 **버튼 하나(「승인」)** 로 합쳤다. 결재선에 검토 단계가 있으면 그 단계에서
`REVIEW` 를, 승인 단계에서 `APPROVE` 를 보낸다(`pendingRoleCd`).
결재자에게 「검토완료」와 「승인」을 따로 보여 주면 무엇을 눌러야 하는지 알 수 없다.

## 폴더

`sign-ready`·`sign-ok` 는 문서함과 같은 `DocumentBoxPage` 를 `mode` 로 쓴다
(`pages/flow/box/documentbox/`). 복제하지 않는다.
`attach/` 만 이 폴더에 있다.

## 화면코드 개명 (2026-08-25)

구 `approval-inbox` → `sign-ready` · `approval-history` → `sign-ok` 로 바꿨다.
DB 는 `db_sasshaccp/127_migrate_appr_screens.sql` 이 화면·권한·메뉴를 같이 옮긴다.

**그리드 pref 키(`doc-approval-inbox`·`doc-approval-history`)는 바꾸지 않았다** —
바꾸면 사용자가 저장해 둔 열 너비가 전부 초기화된다.
API 경로(`/api/v1/docs/documents/approval-inbox`)도 그대로다. 화면코드가 아니라 조회 종류 이름이다.

## 문서 본문 미리보기

결재 2화면은 문서 종류를 몰라도 된다. `ApprovalDocumentPreview` 하나가 `docKind` 로 갈라 준다.

```
ApprovalDocumentPreview
 ├─ HwpDocumentPreview  → HwpEditorPane (작성 화면과 같은 rhwp 패널)
 └─ HtmlDocumentPreview → documentPreviewRegistry → 해당 Paper (읽기전용)
```

- 지면 값은 양식의 현재 모습이 아니라 **문서가 가진 항목 사본**이다.
  상세 SP 가 `tbl_*_item` 에서 읽으므로 나중에 양식을 고쳐도 상신 당시 지면이 유지된다.
  별도 스냅샷 구조를 만들지 않은 이유다.
- 새 HTML 양식군이 생기면 `components/document/documentPreviewRegistry.ts` 에 한 줄만 넣는다.
- HWP 는 rhwp SDK 에 읽기전용 모드가 없어 문구로만 알린다
  (`HwpEditorPane` 의 `ponytail:` 주석 참조). 진짜 잠금이 필요하면 서버 PDF 임베드로 바꾼다.

## 결재 상태·행위

`DOC_STATUS` — `WRK` 작성중 · `REQ` 검토요청 · `REV` 검토완료 · `APV` 승인완료 · `RJT` 반려

| 행위 | SP | 누가 | 조건 |
|---|---|---|---|
| REQUEST 전송 | `sp_tbl_document_approval_c_000` | 작성자 | `WRK`·`RJT` |
| CANCEL 전송취소 | 〃 | 작성자 | `REQ` + 검토·승인 서명 전 |
| REVIEW·APPROVE (화면은 「승인」) | 〃 | 지정 결재자 | 본인 차례 |
| REJECT 반려 | 〃 | 지정 결재자 | 사유 필수 |
| **UNDO 결재취소** | `sp_tbl_document_approval_u_000` | 결재자 본인 | 뒷 단계가 아직 미처리 |

UNDO 는 전용 SP 다. 전이 SP 를 고치지 않는다 — 되돌리기는 검증·복구 규칙이 다르다.
승인을 되돌리면 `tbl_document_version` 의 「승인 완료본」 스냅샷도 같이 걷어낸다.

## 전송 필수값

`attach` 는 지면을 띄우지 않으므로, 전송 직전에 그 문서의 상세를 읽어
작성 화면과 **같은 함수**(`validateForTransfer`)로 검사한다. 규칙을 두 벌로 쓰지 않는다.
지면이 없는 양식(HWP·구양식)은 검사 대상이 아니라 통과시킨다.

서버는 전송 시 상태·작성자·결재선을 검증한다. **지면 필수값까지 서버가 보지는 않는다** —
API 를 직접 호출하면 빈 문서도 상신된다. 막으려면 양식군별 검사 SP 가 필요하다.

## 첨부 파일 저장 위치

DB 에는 경로만 넣고 실제 파일은 **서버 디스크**에 둔다 —
`{저장 루트}/{회사코드}/{연}/{월}/{파일idx}_{원본명}` (`tbl_document_file.file_path`).
저장 루트는 운영 환경변수이고, 컨테이너에서는 업체별 볼륨으로 마운트한다.
다운로드는 항상 인증된 API(`/files/{fileIdx}/download`)를 거친다 — 경로를 화면에 노출하지 않는다.
