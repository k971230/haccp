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
 ├ hwp/         HwpTemplateMapper.xml
 ├ ccp/         CcpColdMapper.xml · CcpGenericMapper.xml · CcpFormsMapper.xml
 ├ prp/         HygieneMapper.xml · HealthCertMapper.xml · BizOpsMapper.xml · EquipmentHistMapper.xml · PestDeviceHistMapper.xml
 ├ sch/         DocCycleMapper.xml
 ├ document/    DocumentMapper.xml
 └ (개선조치는 mapper/flow/ca/DocCorrectiveMapper.xml)
```

`namespace`는 인터페이스 FQCN과 같다. 네이티브 SQL 금지 — SP 호출만.
