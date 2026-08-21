/**
 * ColdMonitorDetail — 냉장보관 일지 상세 묶음.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 헤더 + 점검행(+온도) + 화면용 보관고·한계기준을 한 응답에 담는다
 *   2) 프론트가 열을 그리려면 storages가 필요하고, 상단 문구라서 limits도 함께 보낸다
 *   3) 신규 작성 시 header는 null이고 storages·limits만 채워 기본 양식을 그린다
 *
 * PIPELINE[HB66] ccp DTO
 */
package com.haccp.docs.ccp.dto;

import java.util.ArrayList;
import java.util.List;
import lombok.Data;

@Data
public class ColdMonitorDetail {
    // 헤더 — 신규면 null
    private ColdMonitorHeader header;
    // 점검행
    private List<ColdMonitorRowDto> rows = new ArrayList<>();
    // 열로 쓸 보관고(사용중)
    private List<StorageRow> storages = new ArrayList<>();
    // 한계기준(사용중) — 보통 CCP-1B·CCP-3B
    private List<CcpLimitRow> limits = new ArrayList<>();
    // 이탈 푸터 — 없으면 null
    private DocCorrectiveDto corrective;
}
