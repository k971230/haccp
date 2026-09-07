# mapper/draft — SP 호출 전용 XML

`com.haccp.draft.**` Mapper 인터페이스. 화면(메뉴) 1개 = 폴더 1개.

```
mapper/draft/
 ├ DraftPaperStampMapper.xml           (sp_tbl_document_paper_stamp_*)
 ├ DraftSeenMapper.xml                 (sp_tbl_document_seen_* · assert_seen)
 ├ html/   HtmlDraftMapper.xml
 ├ ccpmonitoring/
 └ hwpdoc/
```

`namespace` 는 인터페이스 FQCN 과 같다. 네이티브 SQL 금지 — SP 호출만.
`selectForms` · `selectDeleteBlocker` 는 SP 결과를 좁히는 래핑 SELECT 다.
