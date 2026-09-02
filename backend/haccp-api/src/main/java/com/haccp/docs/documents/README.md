# document — 문서함·결재·첨부

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/docs/README.md`.

XML `resources/mapper/docs/documents/DocumentMapper.xml`

URL은 `/api/v1/docs/documents/*` · `/api/v1/docs/documents/{idx}/...` 유지.

- `PUT /{docIdx}/remark` — 결재 첨부 비고. `tbl_document.remark`. APV 이후 잠금
- `PUT /{docIdx}/title` — 작성 목록 제목. `tbl_document.title`. 상태와 무관. 작성자만
