/**
 * PeriodHeader — DB형 문서 목록의 기준일 조회 구간을 표준 입력으로 제공한다.
 *
 * @deprecated DocForm 표준은 DocFormSearchToolbar다. 신규 화면에서 사용하지 않는다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 시작일과 종료일 입력을 동일한 간격·라벨로 묶어 목록 조회 조건을 통일한다
 *   2) 날짜 형식 변환과 실제 조회 실행은 소유 화면이 담당해 API 계약을 그대로 유지한다
 *   3) 값 누락·기간 역전 검증을 수행하지 않아 양식별 업무 검증을 변경하지 않는다
 */
// 역할 — 공통 입력
import { Input } from "@/components/ui/Input";
// 역할 — className 병합
import { cn } from "@/lib/cn";

export interface PeriodHeaderProps {
  /** input type=date에 맞춘 시작일 YYYY-MM-DD 값 */
  fromDate: string;
  /** input type=date에 맞춘 종료일 YYYY-MM-DD 값 */
  toDate: string;
  /** 시작일 변경을 소유 화면에 전달하는 함수 */
  onFromDateChange: (value: string) => void;
  /** 종료일 변경을 소유 화면에 전달하는 함수 */
  onToDateChange: (value: string) => void;
  /** 시작일 라벨 — 작성일·점검일 등 양식별 기준명을 지정한다 */
  label?: string;
  /** 전체 기간 입력을 잠글 때 true */
  disabled?: boolean;
  /** 화면별 여백·정렬 보정 클래스 */
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 기준일 시작·종료 입력을 두 label로 렌더링한다
 *   2) 사용자가 날짜를 고르면 브라우저의 YYYY-MM-DD 문자열을 그대로 상위에 전달한다
 *   3) 조회 버튼과 API 호출은 렌더링하지 않아 조회 시점은 화면이 제어한다
 */
export function PeriodHeader({
  // 시작일 — 화면 상태를 input type=date 형식으로 전달한다
  fromDate,
  // 종료일 — 화면 상태를 input type=date 형식으로 전달한다
  toDate,
  // 시작일 변경 함수 — 화면이 API용 포맷으로 정규화한다
  onFromDateChange,
  // 종료일 변경 함수 — 화면이 API용 포맷으로 정규화한다
  onToDateChange,
  // 기준일 라벨 — 기본은 대부분의 문서가 쓰는 작성일
  label = "작성일",
  // 비활성 여부 — 권한·처리 중 상태를 화면이 판단한다
  disabled = false,
  // 추가 클래스 — 검색 바 안쪽 정렬을 조정한다
  className,
}: PeriodHeaderProps) {
  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      <label className="flex flex-col gap-1 text-xs text-slate-600">
        <span>{label}(부터)</span>
        <Input
          // 검색 시작일 — 브라우저 표준 날짜 선택값
          type="date"
          // 화면이 보유한 시작일 값
          value={fromDate}
          // 잠금 여부 — 화면 상태를 반영한다
          disabled={disabled}
          // 시작일 문자열을 소유 화면으로 전달
          onChange={(event) => onFromDateChange(event.target.value)}
          className="w-40"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-600">
        <span>{label}(까지)</span>
        <Input
          // 검색 종료일 — 브라우저 표준 날짜 선택값
          type="date"
          // 화면이 보유한 종료일 값
          value={toDate}
          // 잠금 여부 — 화면 상태를 반영한다
          disabled={disabled}
          // 종료일 문자열을 소유 화면으로 전달
          onChange={(event) => onToDateChange(event.target.value)}
          className="w-40"
        />
      </label>
    </div>
  );
}
