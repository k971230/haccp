# mapper/draft — SP 호출 전용 XML

`com.haccp.draft.**` Mapper 인터페이스. 화면(메뉴) 1개 = 폴더 1개.

```
mapper/draft/
 ├ hyg/    HygProcessDraftMapper.xml   (sp_tbl_hyg_process_*)
 └ ccp/    CcpVerifyDraftMapper.xml    (sp_ccp_verify_*)
```

`namespace` 는 인터페이스 FQCN 과 같다. 네이티브 SQL 금지 — SP 호출만.
`selectForms` · `selectDeleteBlocker` 는 SP 결과를 좁히는 래핑 SELECT 다.
