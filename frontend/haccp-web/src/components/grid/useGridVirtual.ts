/**
 * useGridVirtual — 행 가상화. GRID_VIRTUAL_THRESHOLD 미만이면 전체 렌더.
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) MesEditableGrid·MesDataGrid 가 displayRows.length 로 호출한다
 *   2) 임계는 VITE_GRID_VIRTUAL_THRESHOLD → envConfig (매직 넘버 금지)
 *   3) G-23: 클라이언트 페이지네이션 대신 전체 로드 + 가상 스크롤이 HACCP 정본이다
 *
 * PIPELINE[F91]
 * PIPELINE[F173] 활성 행 스크롤(가상화 시 scrollToIndex)
 */
// 역할 — TanStack Virtual — 대량 행 가상 스크롤
import { useVirtualizer, type Virtualizer } from "@tanstack/react-virtual";
// 역할 — 스크롤 컨테이너 ref 타입
import type { RefObject } from "react";
// 역할 — 가상화 임계 행 수 (VITE_GRID_VIRTUAL_THRESHOLD, 기본 100)
import { GRID_VIRTUAL_THRESHOLD } from "@/config/envConfig";

/**
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) 가상화 활성 임계 행 수 — envConfig GRID_VIRTUAL_THRESHOLD 재export
 *   2) 모듈 import·화면/훅·단위 테스트에서 참조한다
 *   3) .env VITE_GRID_VIRTUAL_THRESHOLD (기본 100), Vite 재시작 필요
 */
// 설명 — 가상화 활성 임계 — OPS_GLOBAL_CONFIG (하드코딩 금지)
export const VIRTUAL_THRESHOLD = GRID_VIRTUAL_THRESHOLD;

/**
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) 행 수·임계·enabled 로 가상화 on/off 를 판정한다
 *   2) useGridVirtual 내부와 G-23 단위 테스트가 호출한다
 *   3) enabled 이고 rowCount >= threshold 이면 true
 */
export function shouldVirtualize(
  // 필터·정렬 후 표시 행 수
  rowCount: number,
  // 임계 — 기본 VIRTUAL_THRESHOLD
  threshold: number = VIRTUAL_THRESHOLD,
  // 화면이 가상화를 끈 경우 false
  enabled = true
): boolean {
  return enabled && rowCount >= threshold;
}
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 행 높이 추정값(px) — estimateSize용
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 행 높이 추정값(px) — estimateSize용
export const ROW_ESTIMATE_PX = 28;

/** useGridVirtual 반환 — active 여부와 virtualizer */
export type GridVirtualApi = {
  active: boolean;
  virtualizer: Virtualizer<HTMLDivElement, Element>;
  paddingTop: number;
  paddingBottom: number;
  virtualRows: { index: number; start: number; size: number; key: string | number | bigint }[];
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 활성 행(activeKey)을 스크롤 영역에 보이게 함 — 신규 추가 시 목록 끝(바닥) 포함
 *   2) MesEditableGrid·MesDataGrid activeKey effect, 행 수 VIRTUAL_THRESHOLD+ 가상화 시
 *   3) 성공 시 해당 행 가시, tr 미마운트면 scrollToIndex 후 rAF로 scrollIntoView
 */
// 설명 — 활성 행으로 스크롤 — 가상화 시 DOM에 없어도 scrollToIndex로 이동(F173)
export function scrollGridToActiveRow(opts: {
  // 그리드 본문 스크롤 컨테이너
  scrollRef: RefObject<HTMLDivElement | null>;
  // 포커스할 행 _key (tr[data-key])
  activeKey: string;
  // displayRows(정렬·필터 후) 기준 0-based 인덱스
  rowIndex: number;
  // useGridVirtual 반환 — active면 virtualizer.scrollToIndex
  virt: Pick<GridVirtualApi, "active" | "virtualizer">;
}): void {
  const { scrollRef, activeKey, rowIndex, virt } = opts;
  // rowIndex 유효하지 않을 때(= 행 없음) 종료
  if (rowIndex < 0) return;

  const intoView = () => {
    const tr = scrollRef.current?.querySelector<HTMLElement>(`tr[data-key="${activeKey}"]`);
    // tr이 있을 때(= 가상화 렌더 완료 또는 전체 렌더) nearest로 맞춤
    tr?.scrollIntoView({ block: "nearest" });
  };

  // 가상화 활성일 때(= VIRTUAL_THRESHOLD 이상) — 미마운트 행은 querySelector 실패하므로 먼저 인덱스로 점프
  if (virt.active) {
    virt.virtualizer.scrollToIndex(rowIndex, { align: "auto" });
    // 가상 행 마운트 후 tr 존재 시 fine-tune (이중 rAF — 레이아웃 반영 대기)
    requestAnimationFrame(() => {
      requestAnimationFrame(intoView);
    });
    return;
  }
  intoView();
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 스크롤 ref·행 수 기준 가상 스크롤 훅 — paddingTop/Bottom·virtualRows 반환
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 스크롤 ref·행 수 기준 가상 스크롤 훅 — paddingTop/Bottom·virtualRows 반환
export function useGridVirtual(
  scrollRef: RefObject<HTMLDivElement | null>,
  rowCount: number,
  enabled = true,
): GridVirtualApi {
  // 임계 미만이면 전체 렌더(active=false)
  const active = shouldVirtualize(rowCount, VIRTUAL_THRESHOLD, enabled);
  const virtualizer = useVirtualizer({
    count: active ? rowCount : 0,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => ROW_ESTIMATE_PX,
    overscan: 8,
  });

// 설명 — 비활성 — padding·virtualRows 빈 값
  if (!active) {
    return {
      active: false,
      virtualizer,
      paddingTop: 0,
      paddingBottom: 0,
      virtualRows: [] as { index: number; start: number; size: number; key: string | number | bigint }[],
    };
  }

// 설명 — 활성 — 보이는 구간 padding·virtualRows 계산
  const items = virtualizer.getVirtualItems();
  const total = virtualizer.getTotalSize();
  const paddingTop = items.length > 0 ? items[0].start : 0;
  const paddingBottom = items.length > 0 ? total - items[items.length - 1].end : 0;

  return {
    active: true,
    virtualizer,
    paddingTop,
    paddingBottom,
    virtualRows: items,
  };
}
