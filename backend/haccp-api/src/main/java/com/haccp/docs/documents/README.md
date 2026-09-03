# document — 문서함·결재·첨부 허브

화면 경로(`/flow/appr/*` · `/flow/box/document-inbox`)와 패키지가 다르다.
결재 4화면이 모두 이 허브 API를 쓴다. 상태 전이는 SP 정본.

XML `resources/mapper/docs/documents/DocumentMapper.xml`

URL은 `/api/v1/docs/documents/*` 유지.

## 화면 ↔ API ↔ SP

| 화면 (scrnCd) | API | SP |
|---|---|---|
| 결재첨부 `attach` | `GET /list` (writerId=본인) · `PUT /approval` REQUEST/CANCEL · files/remark | `sp_tbl_document_r_000` · `sp_tbl_document_approval_c_000` |
| 결재대기 `sign-ready` | `GET /sign-ready` · `PUT /approval` APPROVE/REJECT | `sp_sign_ready_r_000` |
| 결재완료 `sign-ok` | `GET /sign-ok` · `PUT /approval` UNDO | `sp_sign_ok_r_000` |
| 문서함 `document-inbox` | `GET /list?status=APV` | `sp_tbl_document_r_000` |

상태: WRK --REQUEST--> REQ --APPROVE--> APV / --REJECT--> RJT. REQ --CANCEL--> WRK. APV --UNDO--> REQ.

- `PUT /{docIdx}/remark` — 결재 첨부 비고. `tbl_document.remark`. APV 이후 잠금
- `PUT /{docIdx}/title` — 작성 목록 제목. `tbl_document.title`. 상태와 무관. 작성자만
- `POST /{docIdx}/export-pdf` — HWP 본문 → PDF. 결재 잠금이면 기존 PDF 재사용, 없으면 완료본만 등록
  (본문·사용자첨부는 그대로 잠금)
