# mapper/draft/ccpmonitoring

| XML | 인터페이스 | SP |
|---|---|---|
| `CcpPkgDraftMapper.xml` | `CcpPkgDraftMapper` | 목록 `sp_ccp_pkg_log_r_000` · 상세/저장/삭제 `sp_tbl_ccp_pkg_monitor_*` |
| `CcpHtgDraftMapper.xml` | `CcpHtgDraftMapper` | 목록 `sp_ccp_htg_log_r_000` · 상세/저장/삭제 `sp_tbl_ccp_htg_monitor_*` |
| `CcpMtlDraftMapper.xml` | `CcpMtlDraftMapper` | 목록 `sp_ccp_mtl_r_000` · 헤더/감도/통과량 `sp_tbl_ccp_metal_monitor_*` |

`namespace` 는 인터페이스 FQCN 과 같다. 네이티브 SQL 은 삭제 차단 래핑 SELECT 뿐이다.
