/**
 * CcpPkgDraftMapper — CCP 포장 작성 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 데이터는 tbl_ccp_pkg_monitor(+_row·_cell)
 *   2) 목록 sp_ccp_pkg_log_r_000 · 상세/저장/삭제 sp_tbl_ccp_pkg_monitor_*
 *   3) 가열·금속 매퍼와 표를 공유하지 않는다
 *
 * PIPELINE[HB139] CCP 포장 작성 Mapper
 */
package com.haccp.draft.ccpmonitoring;

import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface CcpPkgDraftMapper extends CcpMonitorStore {
}
