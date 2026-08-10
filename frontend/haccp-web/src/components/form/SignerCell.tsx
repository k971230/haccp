/**
 * SignerCell — 문서 담당자·점검자·결재자의 이름 입력 셀을 표준화한다.
 *
 * @deprecated DocForm 표준은 DocCellInput(+행 서명 버튼)이다. 신규 화면에서 사용하지 않는다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 서명 역할 라벨과 이름 입력을 같은 밀도의 폼 필드로 제공한다
 *   2) 결재 진행 문서는 disabled 상태로 이름을 표시해 작성 당시 스냅샷을 보존한다
 *   3) 직원 조회·전자서명·저장 API는 포함하지 않아 양식별 결재 흐름을 바꾸지 않는다
 */
// 역할 — 공통 입력
import { Input } from "@/components/ui/Input";
// 역할 — className 병합
import { cn } from "@/lib/cn";

export interface SignerCellProps {
  /** 담당자·점검자·검토자처럼 입력의 업무 역할을 나타내는 라벨 */
  label: string;
  /** 문서에 저장할 서명자 이름 또는 표시명 */
  value: string;
  /** 이름 변경을 소유 화면 상태로 전달하는 함수 */
  onChange: (value: string) => void;
  /** 결재 잠금·권한 부족일 때 입력을 막는 상태 */
  disabled?: boolean;
  /** 빈 입력에 보여줄 업무 안내 */
  placeholder?: string;
  /** 필수 서명자 여부 — label 뒤에 필수 표기를 붙인다 */
  required?: boolean;
  /** 화면별 필드 폭 보정 클래스 */
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 서명 역할과 이름 입력을 label로 연결해 클릭과 화면 읽기 접근성을 제공한다
 *   2) 값 변경은 이름 문자열만 상위로 전달해 DTO 필드 결정은 양식이 담당한다
 *   3) 비활성일 때도 저장된 이름을 보여 결재 중 문서의 책임자를 확인할 수 있다
 */
export function SignerCell({
  // 역할 라벨 — 담당자·점검자·결재자 등 양식에서 지정한다
  label,
  // 현재 이름 — 문서 헤더 또는 행 스냅샷 값
  value,
  // 이름 변경 콜백 — 화면의 상태 setter 또는 행 patch 함수
  onChange,
  // 편집 가능 여부 — 결재 잠금·권한 상태를 화면이 판단한다
  disabled = false,
  // 빈값 안내 — 필요한 경우만 양식이 전달한다
  placeholder,
  // 필수 여부 — 누락 시 사용자가 알 수 있도록 라벨에 표시한다
  required = false,
  // 추가 클래스 — 필드 폭 등 화면 배치 보정
  className,
}: SignerCellProps) {
  return (
    <label className={cn("flex flex-col gap-1 text-xs text-slate-600", className)}>
      <span>
        {label}
        {required && <span className="ml-0.5 text-red-600">*</span>}
      </span>
      <Input
        // 서명자 이름 — 소유 화면의 문서 또는 행 상태와 양방향 연결
        value={value}
        // 결재 잠금·권한 부족일 때 수정 금지
        disabled={disabled}
        // 빈 서명자 입력 안내
        placeholder={placeholder}
        // 입력 문자열을 그대로 상위 상태에 전달
        onChange={(event) => onChange(event.target.value)}
        className="w-40"
      />
    </label>
  );
}
