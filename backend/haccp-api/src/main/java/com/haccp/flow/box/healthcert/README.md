# flow.box.healthcert — 보건증 등록 관리

화면 `/flow/box/health-cert-management`.

처리 근거는 식품위생법 제40조. 주민번호 칸은 없다. PDF 원본 바이트만
파일별 DEK 로 AES-GCM 봉투를 씌우고, DEK 는 `APP_HR_FILE_KEY` 로 감싸
`wrapped_dek` 에 둔다. 디스크 파일명은 UUID. 열람·등록·삭제는 `tbl_audit_log` (VIEW/I/D).
삭제는 담당자만. 대체된 이력은 `APP_HR_RETENTION_DAYS`(기본 730) 후 파기.

- 이력·파일: 본인 또는 `tbl_health_cert_mgr` 담당자만. ADMIN 이라도 담당자가 아니면 타 직원 파일을 못 연다
- 담당자 지정: ADMIN 만. 담당자가 담당자를 추가하지 못한다
- 파일: PDF 만. `HealthCertFileStorage` → `{APP_FILE_ROOT}/HrDocs/{co_cd}/health-cert/{일자}/{uuid}.pdf`
- 업로드: `{uuid}.pdf.tmp` 에 다 쓴 뒤 rename. INSERT 실패 시 실물 삭제
- 키: 파일별 DEK. 마스터는 `APP_HR_FILE_KEY`. 세대 `key_version`. 교체 시 `APP_HR_FILE_KEY_PREV`
- 알림: 기존 10분 크론이 `sp_health_cert_management_alarm_send_c_000` 을 부른다. 사원별 최신 이력 1건만
- 파기: 같은 크론이 `sp_health_cert_management_hist_purge_d_000`
