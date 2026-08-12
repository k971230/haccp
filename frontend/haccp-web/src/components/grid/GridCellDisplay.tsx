/**
 * GridCellDisplay.tsx — 그리드 셀 표시(텍스트·상태 배지).
 
 * PIPELINE[F166]
 */
// 역할 — 활성 행 화살표 아이콘
import { ChevronRight } from "lucide-react";
// 역할 — 그리드 컬럼 정의 타입
import type { GridColumn } from "@/types/grid";
// 역할 — className 병합
import { cn } from "@/lib/cn";

// 설명 — 상태 배지 색상 톤
export type GridBadgeTone = "blue" | "amber" | "green" | "gray" | "red" | "purple";

// 설명 — 한글 상태 라벨 → 기본 배지 톤 매핑
const LABEL_TONES: Record<string, GridBadgeTone> = {
  진행: "blue",
  확정: "amber",
  완료: "green",
  종료: "green",
  대기: "gray",
  취소: "red",
  불량: "red",
  합격: "green",
  불합격: "red",
};

// 설명 — badge 설정·값·라벨로 배지 톤 결정 — 없으면 null(일반 텍스트)
function resolveBadgeTone(
  value: unknown,
  label: string,
  badge?: boolean | Partial<Record<string, GridBadgeTone>>,
  // code+badge:true 일 때(= 권한·부서·서명 팝업 코드) 기본 보라
  preferPurple?: boolean,
): GridBadgeTone | null {
  if (!badge) return null;
  if (typeof badge === "object") {
    const byCode = badge[String(value ?? "")];
    if (byCode) return byCode;
    const byLabel = badge[label];
    if (byLabel) return byLabel;
  }
  const byStatus = LABEL_TONES[label];
  if (byStatus) return byStatus;
  // 명시 badge:true 코드 컬럼 — 보라 / 그 외 회색
  if (preferPurple || badge === true) return "purple";
  return "gray";
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 상태 배지 span — tone별 CSS 클래스
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 상태 배지 span — tone별 CSS 클래스
export function GridBadge({ label, tone }: { label: string; tone: GridBadgeTone }) {
  return (
    <span className={cn("mes-grid-badge", `mes-grid-badge-${tone}`)}>
      {label}
    </span>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 셀 표시 — code+상태 컬럼은 자동 배지, 그 외 텍스트
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 셀 표시 — code+상태 컬럼은 자동 배지, 그 외 텍스트
export function GridCellDisplay<T extends Record<string, unknown>>({
  // row — 호출부/컴포넌트에 전달되는 의미 있는 값
  // 변경 시 화면·훅 동작에 영향 — 기본값·nullable 여부 확인
  row,
  // col — 호출부/컴포넌트에 전달되는 의미 있는 값
  // 변경 시 화면·훅 동작에 영향 — 기본값·nullable 여부 확인
  col,
  // text — 호출부/컴포넌트에 전달되는 의미 있는 값
  // 변경 시 화면·훅 동작에 영향 — 기본값·nullable 여부 확인
  text,
}: {
  row: T;
  col: GridColumn<T>;
  text: string;
}) {
  const autoBadge = col.type === "code" && (col.header.includes("상태") || /_(STAT|STATE)$/i.test(col.field));
  const useBadge = col.badge ?? autoBadge;
  // 명시 badge:true + code — 권한그룹·부서·서명 등 보라 뱃지
  const preferPurple = col.badge === true && col.type === "code" && !autoBadge;
  const tone = useBadge
    ? resolveBadgeTone(row[col.field], text, col.badge ?? true, preferPurple)
    : null;
  if (tone && text) return <GridBadge label={text} tone={tone} />;
  return <span className="mes-cell-text">{text}</span>;
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 행번호 셀 — 활성 행이면 ChevronRight, 아니면 순번
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 행번호 셀 — 활성 행이면 ChevronRight, 아니면 순번
export function GridRowNumCell({ index, active }: { index: number; active: boolean }) {
  return (
    <td className={cn("mes-rownum", active && "mes-rownum-active")}>
      {active ? (
        <ChevronRight className="mx-auto h-3.5 w-3.5 text-blue-700" aria-hidden />
      ) : (
        <span className="mes-rownum-index">{index + 1}</span>
      )}
    </td>
  );
}
