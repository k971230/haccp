/**
 * useSection — 마스터·디테일 그리드 한 쌍을 잡는 훅 별칭.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) useActiveGrid 를 h(마스터)·d(디테일) 별칭으로 다시 내보낸다
 *   2) 두 그리드를 쓰는 화면이 호출한다 — 한 그리드면 useActiveGrid 를 바로 쓴다
 *   3) 계약은 mes-web useSection 과 같다. 여기서 로직을 더하지 않는다
 *
 * PIPELINE[HF76] 셸 인프라
 * PIPELINE[HF49, HF52] 연관 모듈
 */
// useActiveGrid: useSection(h/d 마스터·디테일 별칭)
export { useSection } from "@/shell/useActiveGrid";
