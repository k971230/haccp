/**
 * StorageRow — 보관고 목록 행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) sp_tbl_storage_r_000 결과 — 냉장보관 일지 열 머리글의 근거
 *   2) tempMin·tempMax가 있으면 셀 판정에 보관고 개별범위를 쓴다
 *   3) sortNo 순으로 화면 열을 그린다
 *
 * PIPELINE[HB60] ccp DTO
 */
package com.haccp.docs.ccp.dto;

import java.math.BigDecimal;
import lombok.Data;

@Data
public class StorageRow {
    // PK 대리키
    private Long idx;
    // 회사코드
    private String coCd;
    // 보관고 코드 — 온도행 storageCd
    private String storageCd;
    // 보관고명 — 열 머리글
    private String storageNm;
    // 유형 COLD/FROZEN/ROOM
    private String storageType;
    // 연결 CCP 코드
    private String ccpCd;
    // 위치 표기 — 열 머리글 보조
    private String placeNm;
    // 개별 하한온도 — null이면 한계기준 사용
    private BigDecimal tempMin;
    // 개별 상한온도
    private BigDecimal tempMax;
    // 열 순서
    private Integer sortNo;
    // 사용여부
    private String useYn;
}
