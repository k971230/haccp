/**
 * DocCell — 문서 표 셀에 녹아 든 입력·선택·시간 컨트롤.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 떠 있는 textbox 대신 서식 셀 안 borderless 입력을 제공한다
 *   2) DB형 본문 표·메타 표가 DocCellInput·Select·Time을 공통으로 사용한다
 *   3) 값 검증·저장은 소유 화면이 담당한다
 *
 * PIPELINE[HF122] 문서 셀 입력
 * PIPELINE[HF120] 연관 모듈
 */
// 역할 — React 노드·입력 이벤트
import { Fragment, type ChangeEvent, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — type=time ↔ HHMM/HH:MM 저장 변환
import { fromInputTimeHhmm, fromInputTimeHm, toInputTime } from "@/lib/docDateTime";

export interface DocCellInputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "onChange" | "value"> {
  // 현재 값 — null은 빈 문자열로 렌더
  value: string | number | null | undefined;
  // 변경 값 문자열
  onChange: (value: string) => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서 셀용 input을 렌더링한다
 *   2) 점검표·메타 표 셀에서 호출한다
 *   3) disabled여도 값은 보이게 유지한다
 */
export function DocCellInput({
  // 표시·편집 값
  value,
  // 변경 콜백
  onChange,
  // 추가 클래스
  className,
  ...rest
}: DocCellInputProps) {
  const handleChange = (event: ChangeEvent<HTMLInputElement>) => onChange(event.target.value);
  return (
    <input
      {...rest}
      // 셀 값 — null은 빈 문자열
      value={value ?? ""}
      // 변경 전달
      onChange={handleChange}
      // 문서 셀 스타일
      className={cn("doc-cell-input", className)}
    />
  );
}

export interface DocCellSelectProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, "onChange" | "value"> {
  // 현재 선택 값 — null은 빈 선택
  value: string | null | undefined;
  // 변경 값
  onChange: (value: string) => void;
  // option 목록
  options: Array<{ value: string; label: string }>;
  // 빈 선택 라벨
  emptyLabel?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서 셀용 select를 렌더링한다
 *   2) 판정·구분 코드 선택에 쓴다
 *   3) 빈 값은 emptyLabel로 표시한다
 */
export function DocCellSelect({
  // 선택 값
  value,
  // 변경
  onChange,
  // 옵션
  options,
  // 미선택 문구
  emptyLabel = "-",
  // 클래스
  className,
  ...rest
}: DocCellSelectProps) {
  return (
    <select
      {...rest}
      // 선택 값
      value={value ?? ""}
      // 코드 전달
      onChange={(event) => onChange(event.target.value)}
      // 문서 셀 스타일
      className={cn("doc-cell-select", className)}
    >
      <option value="">{emptyLabel}</option>
      {options.map((option) => (
        <option key={option.value} value={option.value}>{option.label}</option>
      ))}
    </select>
  );
}

/** DocCellTime 저장 형식 — hhmm=HHMM 4자리, hm=HH:MM */
export type DocCellTimeStorage = "hhmm" | "hm";

export interface DocCellTimeProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "onChange" | "value" | "type"> {
  // 저장 형식의 현재 값 — null은 빈 선택
  value: string | null | undefined;
  // 저장 형식으로 변경 전달
  onChange: (value: string) => void;
  // DB 저장 형식 — 기본 hhmm(Cold·Metal·Hygiene)
  storage?: DocCellTimeStorage;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 문서 셀용 type=time 콤보를 렌더링한다
 *   2) CCP·위생 점검시간에 쓴다
 *   3) value/onChange는 storage 형식(HHMM 또는 HH:MM)이다
 */
export function DocCellTime({
  // 저장 형식 값
  value,
  // 저장 형식 변경
  onChange,
  // HHMM | HH:MM
  storage = "hhmm",
  // 클래스
  className,
  ...rest
}: DocCellTimeProps) {
  // 표시용 HH:MM — input type=time
  const display = toInputTime(value);
  const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
    const next = event.target.value;
    // storage에 맞게 저장 문자열로 변환
    onChange(storage === "hm" ? fromInputTimeHm(next) : fromInputTimeHhmm(next));
  };
  return (
    <input
      {...rest}
      // 브라우저 시간 콤보
      type="time"
      // 표시 값 HH:MM
      value={display}
      // 저장 형식 전달
      onChange={handleChange}
      // 문서 셀 스타일
      className={cn("doc-cell-input", className)}
    />
  );
}

export interface DocMetaTableProps {
  // 라벨·값 쌍 — 작성일·담당 등
  rows: Array<{ label: string; node: ReactNode }>;
  // 한 행에 둘 라벨+값 쌍 개수
  pairsPerRow?: 1 | 2;
  // 클래스
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서 상단 메타 정보 표를 그린다
 *   2) DocPaper 본문 최상단에서 호출한다
 *   3) 레이아웃만 담당한다
 */
export function DocMetaTable({
  // 메타 행
  rows,
  // 한 줄 쌍 수
  pairsPerRow = 2,
  // 클래스
  className,
}: DocMetaTableProps) {
  const chunks: Array<typeof rows> = [];
  for (let i = 0; i < rows.length; i += pairsPerRow) {
    chunks.push(rows.slice(i, i + pairsPerRow));
  }
  return (
    <table className={cn("doc-table doc-meta-table", className)}>
      <tbody>
        {chunks.map((chunk, index) => (
          <tr key={index}>
            {chunk.map((row) => (
              <Fragment key={row.label}>
                <th>{row.label}</th>
                <td>{row.node}</td>
              </Fragment>
            ))}
            {chunk.length < pairsPerRow
              ? Array.from({ length: pairsPerRow - chunk.length }).map((_, pad) => (
                  <Fragment key={`pad-${pad}`}>
                    <th />
                    <td />
                  </Fragment>
                ))
              : null}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
