# mapper/docs — SP 호출 전용 XML

`com.haccp.docs.**` Mapper 인터페이스. 화면(메뉴) 1개 = 폴더 1개.

```
mapper/docs/
 ├ htmlform/htmltemplate/        HtmlTemplateMapper.xml
 ├ htmlform/ccpverifytemplate/   CcpVerifyTemplateMapper.xml
 ├ htmlform/ccppkgtemplate/      CcpPkgTemplateMapper.xml
 ├ htmlform/ccphtgtemplate/      CcpHtgTemplateMapper.xml
 ├ htmlform/ccpmtltemplate/      CcpMtlTemplateMapper.xml
 ├ hwp/          HwpTemplateMapper.xml
 ├ sch/          DocCycleMapper.xml
 └ documents/    DocumentMapper.xml

작성 매퍼는 `mapper/draft/`, 개선조치는 `mapper/flow/ca/`. 폴더는 `htmlform`, URL 만 `html-form` 이다.
```

`namespace`는 인터페이스 FQCN과 같다. 네이티브 SQL 금지 — SP 호출만.
