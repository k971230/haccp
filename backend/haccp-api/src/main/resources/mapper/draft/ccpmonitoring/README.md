# mapper/draft/ccpmonitoring

| XML | 인터페이스 | SP |
|---|---|---|
| `CcpLogDraftMapper.xml` | `CcpLogDraftMapper` | 목록 `sp_ccp_log_r_000` · 상세/저장/삭제 `sp_tbl_ccp_generic_monitor_r_000/_c_000/_d_000` |
| `CcpMtlDraftMapper.xml` | `CcpMtlDraftMapper` | 목록 `sp_ccp_mtl_r_000` · 헤더/감도/통과량 `sp_tbl_ccp_metal_monitor_r_001/_r_002/_r_003` · 저장/삭제 `_c_000`/`_d_000` |

양식 목록·항목만 계열 SP 가 달라 `CcpLogDraftMapper.xml` 이 `choose` 로 pkg/htg 를 가른다.
`namespace` 는 인터페이스 FQCN 과 같다. 네이티브 SQL 은 삭제 차단 래핑 SELECT 뿐이다.
