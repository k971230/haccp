/**
 * useSection — MES 셸 인프라 모듈.
 *
 * 주요 역할:
 *     1. MesShell(F49) / Page(F115~F156) 지원 유틸
 *     2. 탭·다이얼로그·메시지·검증·단축키 등 횡단 관심사
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음.
 *     - *Page.tsx가 shell을 import(단방향).
 *
 * PIPELINE[HF76] 셸 인프라 — mes-web useSection와 동일 계약
 * PIPELINE[HF49, HF52] 연관 모듈
 *
 * 구현내용: 전수 주석(레벨3). useActiveGrid의 h/d 별칭 재export.
 */
// useActiveGrid: useSection(h/d 마스터·디테일 별칭)
export { useSection } from "@/shell/useActiveGrid";
