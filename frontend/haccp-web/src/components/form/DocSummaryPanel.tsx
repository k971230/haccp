/**
 * DocSummaryPanel — DB형 문서의 식별·판정·필수값 현황을 우측 패널로 표시한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 목업처럼 상태·문서번호·자동판정·필수입력 완료도를 카드형으로 보여준다
 *   2) 저장 전에는 채번 안내·대시를 써서 실제 저장값과 혼동하지 않게 한다
 *   3) 상태 변경이나 판정 계산을 하지 않고 읽기 전용 값만 표시한다
 *
 * PIPELINE[HF123] 문서 요약 패널
 * PIPELINE[HF119] 연관 모듈
 */
// 역할 — JSX 요소 타입
import type { ReactNode } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";

export interface RequiredFieldProgress {
  // 입력을 완료한 필수 항목 개수
  completed: number;
  // 현재 양식에서 검증하는 필수 항목 전체 개수
  total: number;
}

export interface DocSummaryPanelProps {
  // 서버가 채번한 문서번호 — 신규 문서는 빈 문자열
  documentNumber?: string | null;
  // 문서 상태의 업무 표시명
  statusLabel: string;
  // 서버에서 받은 최근 저장 시각
  savedAt?: string | null;
  // 자동 판정 표시값
  automaticJudgement?: string | null;
  // 결재선 표시 문구
  approvalLine?: string | null;
  // 필수 항목 완료 수와 전체 수
  requiredFieldProgress?: RequiredFieldProgress;
  // 안내 문구(자동판정 설명 등)
  hint?: string | null;
  // 추가 슬롯
  children?: ReactNode;
  // 화면별 폭·정렬 보완 클래스
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서 요약 카드를 렌더링한다
 *   2) DocFormSidePanel 안에서 호출한다
 *   3) 업무 상태를 바꾸지 않는다
 */
export function DocSummaryPanel({
  // 문서번호
  documentNumber,
  // 상태 업무명
  statusLabel,
  // 최근 저장
  savedAt,
  // 자동 판정
  automaticJudgement,
  // 결재선
  approvalLine,
  // 필수 항목
  requiredFieldProgress,
  // 안내
  hint,
  // 추가
  children,
  // 클래스
  className,
}: DocSummaryPanelProps) {
  const isComplete =
    requiredFieldProgress != null &&
    requiredFieldProgress.total > 0 &&
    requiredFieldProgress.completed >= requiredFieldProgress.total;

  return (
    <div className={cn("space-y-4 text-xs text-slate-700", className)}>
      <div>
        <h3 className="text-sm font-semibold text-slate-800">문서 정보</h3>
        <dl className="mt-2 space-y-1.5">
          <div className="flex justify-between gap-2"><dt className="text-slate-500">상태</dt><dd className="font-medium">{statusLabel}</dd></div>
          <div className="flex justify-between gap-2"><dt className="text-slate-500">문서번호</dt><dd>{documentNumber || "(저장 시 채번)"}</dd></div>
          <div className="flex justify-between gap-2"><dt className="text-slate-500">최근 저장</dt><dd>{savedAt || "-"}</dd></div>
          {approvalLine ? (
            <div className="flex justify-between gap-2"><dt className="text-slate-500">결재선</dt><dd className="text-right">{approvalLine}</dd></div>
          ) : null}
          <div className="flex justify-between gap-2"><dt className="text-slate-500">자동 판정</dt><dd>{automaticJudgement || "미판정"}</dd></div>
        </dl>
      </div>
      {requiredFieldProgress ? (
        <div>
          <h3 className="text-sm font-semibold text-slate-800">필수입력 점검</h3>
          <p className={cn("mt-2 font-medium", isComplete ? "text-emerald-700" : "text-amber-700")}>
            {requiredFieldProgress.completed}/{requiredFieldProgress.total} 완료
          </p>
          <div className="mt-2 h-2 overflow-hidden rounded bg-slate-100">
            <div
              className={cn("h-full", isComplete ? "bg-emerald-500" : "bg-amber-400")}
              style={{
                width: `${requiredFieldProgress.total > 0
                  ? Math.min(100, Math.round((requiredFieldProgress.completed / requiredFieldProgress.total) * 100))
                  : 0}%`,
              }}
            />
          </div>
        </div>
      ) : null}
      {hint ? <p className="rounded bg-slate-50 p-2 leading-relaxed text-slate-500">{hint}</p> : null}
      {children}
    </div>
  );
}
