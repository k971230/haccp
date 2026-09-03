# templates

classpath 템플릿·매니페스트(TSV 등).

`manifest.tsv` 1행 = 표준 양식 1건. 배포 경로는 `APP_FILE_ROOT/HaccpTemplates/{tmpl_cd}/{target_name}` —
`tmpl_cd`는 `tbl_template.tmpl_cd`(양식 파일 관리 화면의 양식코드)와 같아야 한다.
자사 커스텀은 `CustomTemplates/{co_cd}/{tmpl_cd}/`, 작성 문서·첨부는 `HaccpLogBooks/{co_cd}/{일자}/{tmpl_cd}/`.
`doc_kind='HTML'` 양식은 물리 원본을 참조하지 않으므로 `form_path`가 NULL이다.

## 관련
- 정본: `.cursor/rules/08-haccp-backend.mdc` · `.cursor/rules/06-operations.mdc`
