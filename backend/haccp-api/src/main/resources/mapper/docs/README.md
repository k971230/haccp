# mapper/docs — SP 호출 전용 XML

`com.haccp.docs.**` Mapper 인터페이스. 화면(메뉴) 1개 = 폴더 1개.

```
mapper/docs/
 ├ html/htmltemplate/        HtmlTemplateMapper.xml
 ├ html/ccpverifytemplate/   CcpVerifyTemplateMapper.xml
 ├ html/ccppkgtemplate/      CcpPkgTemplateMapper.xml
 ├ html/ccphtgtemplate/      CcpHtgTemplateMapper.xml
 ├ html/ccpmtltemplate/      CcpMtlTemplateMapper.xml
 ├ html/hygprocess/          HygProcessMapper.xml
 ├ hwptemplate/ HwpTemplateMapper.xml
 ├ doccycle/    DocCycleMapper.xml
 ├ document/    DocumentMapper.xml
 └ corrective/  DocCorrectiveMapper.xml
```

`namespace`는 인터페이스 FQCN과 같다. 네이티브 SQL 금지 — SP 호출만.
