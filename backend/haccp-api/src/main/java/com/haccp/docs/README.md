# com.haccp.docs — 문서 관리

정본: FE `frontend/haccp-web/src/pages/docs/README.md`

```
com/haccp/docs/
 ├ hwp/                          사용양식 관리 — URL /api/v1/docs/hwp/hwp-template-management
 ├ sch/                          문서주기 — URL /api/v1/docs/sch/schedule-cycle-management
 ├ htmlform/htmltemplate         HTML양식 원본 Controller·Service — URL /api/v1/docs/html-form/{scrnCd} 5화면
 ├ htmlform/ccpverifytemplate    CCP 검증점검 양식 Mapper (Controller는 htmltemplate 공유)
 ├ htmlform/ccppkgtemplate       CCP-1B 포장일지 Mapper
 ├ htmlform/ccphtgtemplate       CCP-2B 가열일지 Mapper
 ├ htmlform/ccpmtltemplate       CCP-3P 금속검출일지 Mapper
 ├ documents/                    문서함·결재·첨부 — URL /api/v1/docs/documents
 └ templates/                    양식 파일 저장 — URL /api/v1/docs/templates
```

**패키지·XML 폴더는 `htmlform`, HTTP 경로만 `html-form` 이다.**
작성 화면은 `com.haccp.draft` 다 — 여기가 아니다.

XML `resources/mapper/docs/{같은 폴더명}/`. 폴더 이동만으로 HTTP 경로를 바꾸지 않는다.

사용양식 삭제는 화면 자기 경로 `/api/v1/docs/hwp/hwp-template-management/{validate-delete,delete}` 다.
