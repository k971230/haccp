/**
 * JudgeSelect — 수동 판정이 필요한 DB형 양식의 표준 판정 선택기.
 *
 * @deprecated DocForm 표준은 DocCellSelect(O/X)다. 신규 화면에서 사용하지 않는다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 양식마다 다른 적합·부적합 코드와 표시명을 option 목록으로 받아 선택한다
 *   2) 자동 판정 양식은 disabled로 표시 전용으로도 사용할 수 있다
 *   3) 판정 규칙과 저장 요청은 소유 화면이 처리하므로 이 컴포넌트는 값만 전달한다
 */
// 역할 — 변경 이벤트 타입
import type { ChangeEvent } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";

export interface JudgeOption {
  /** DB 저장에 사용하는 판정 코드 */
  value: string;
  /** 사용자에게 표시할 판정명 */
  label: string;
  /** 적합·부적합·중립 상태의 글자색 */
  tone?: "pass" | "fail" | "neutral";
}

export interface JudgeSelectProps {
  /** 현재 선택한 판정 코드 — 미판정은 빈 문자열 또는 null */
  value?: string | null;
  /** 사용자가 선택한 판정 코드를 소유 화면으로 전달하는 함수 */
  onChange: (value: string) => void;
  /** 양식별 판정 코드와 표시명 목록 */
  options: JudgeOption[];
  /** 자동 판정·결재 잠금 등으로 수정할 수 없을 때 true */
  disabled?: boolean;
  /** 연결 label이 없을 때 스크린 리더가 읽을 판정 항목명 */
  ariaLabel: string;
  /** 화면별 셀 폭 보정 클래스 */
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 판정 코드 선택을 native select로 제공해 키보드 조작과 화면 읽기를 보장한다
 *   2) 빈 값은 미판정으로 표시해 사용자가 아직 선택하지 않았음을 명확히 한다
 *   3) disabled여도 현재 판정은 유지해 결재 잠금 문서의 결과를 확인할 수 있다
 */
export function JudgeSelect({
  // 현재 판정 코드 — null은 미판정 선택지로 정규화한다
  value,
  // 판정 변경 콜백 — event 대신 코드만 전달해 화면 상태 갱신을 단순하게 한다
  onChange,
  // 양식별 코드 목록 — O/X, P/F 등 서로 다른 코드 체계를 수용한다
  options,
  // 편집 금지 — 자동 판정 또는 결재 상태 잠금일 때 true
  disabled = false,
  // 접근성 이름 — 표 셀 안에서 별도 label이 없는 경우에 필요하다
  ariaLabel,
  // 추가 클래스 — 표 셀 폭 등 최소한의 화면 보정
  className,
}: JudgeSelectProps) {
  const selectedOption = options.find((option) => option.value === value);
  const toneClass =
    selectedOption?.tone === "pass"
      ? "text-emerald-700"
      : selectedOption?.tone === "fail"
        ? "text-red-700"
        : "text-slate-700";

  const handleChange = (event: ChangeEvent<HTMLSelectElement>) => {
    onChange(event.target.value);
  };

  return (
    <select
      // 선택값 — null은 빈 미판정 선택지에 연결한다
      value={value ?? ""}
      // 변경 이벤트 — 판정 코드만 상위 상태에 전달한다
      onChange={handleChange}
      // 편집 잠금 — 자동 판정·결재 진행 문서에 적용한다
      disabled={disabled}
      // 표 안 판정 셀의 접근성 이름
      aria-label={ariaLabel}
      // 표준 입력 높이·테두리와 현재 판정 색상
      className={cn(
        "h-mes-input rounded border border-slate-300 bg-white px-2 text-xs font-medium outline-none focus:border-brand-700 focus:ring-2 focus:ring-brand-100 disabled:bg-slate-100 disabled:text-slate-500",
        toneClass,
        className
      )}
    >
      <option value="">미판정</option>
      {options.map((option) => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </select>
  );
}
