# com.haccp.docs — 문서 관리

정본: FE `frontend/haccp-web/src/pages/docs/README.md`

```
com/haccp/docs/
 ├ hwptemplate/              사용양식 관리 — URL /api/v1/hwp/...
 ├ html/htmltemplate         HTML양식 원본 Controller·Service — URL /api/v1/docs/html-form
 ├ html/ccpverifytemplate    CCP 검증점검 양식 Mapper (Controller는 htmltemplate 공유)
 ├ html/ccppkgtemplate       CCP-1B 포장일지 Mapper
 ├ html/ccphtgtemplate       CCP-2B 가열일지 Mapper
 ├ html/ccpmtltemplate       CCP-3P 금속검출일지 Mapper
 ├ html/hygprocess           공정점검 작성 — URL /api/v1/docs/hyg-process
 ├ doccycle/                 문서주기 — URL /api/v1/hwp/doc-cycles
 ├ document/                 문서함·결재·첨부 — URL /api/v1/doc/documents
 ├ template/                 양식 파일 저장 — URL /api/v1/doc/templates
 └ corrective/               개선조치 SP 지원
```

XML `resources/mapper/docs/{같은 폴더명}/`. 폴더 이동만으로 HTTP 경로를 바꾸지 않는다.

삭제는 사용양식·법적서류가 `/api/v1/bas/company-templates/*` 를 Workflow에 공유한다.
