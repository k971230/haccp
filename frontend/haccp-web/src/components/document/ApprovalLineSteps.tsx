/**
 * ApprovalLineSteps — 문서 결재 단계를 첨부화면과 같은 가로 순서형 스테퍼로 그린다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 결재 이력은 가로 스테퍼 + 그 아래 읽기 표다. 칸 10px 잘림을 표가 보완한다
 *   2) 문서함·결재대기·결재완료 상세가 같은 컴포넌트를 쓴다. 화면마다 복제하지 않는다
 *   3) 칸 수·라벨은 호출측이 넘긴다. 색은 stepperTone 한 곳
 *
 * PIPELINE[HF187] 문서함 결재 스테퍼
 * PIPELINE[HF185] 연관 — 결재 첨부 진행상태 마크업
 */
// 역할 — 그리드 헤더와 같은 파란 막대
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 첨부화면과 같은 스테퍼 칸 색
import { stepperToneClass, type StepperTone } from "@/components/document/stepperTone";

/** 결재 스테퍼 칸 상태 — 완료·현재·대기·반려. 첨부화면과 같은 네 값 */
export type ApprovalLineTone = StepperTone;

/** 결재 스테퍼 한 칸 — 역할·담당자·결과·의견 */
export type ApprovalLineStepView = {
  key: string;
  label: string;
  tone: ApprovalLineTone;
  caption: string;
  detail: string;
  opinion: string;
  // 이력 표 결과 칸 — 스테퍼 detail 과 달리 시각을 붙이지 않는다
  resultNm: string;
  // 이력 표 시각 칸 — YYYY-MM-DD HH:MM. 없으면 빈 문자열
  actDisp: string;
};

interface ApprovalLineStepsProps {
  // 결재 단계 칸 — 없으면 빈 안내만
  steps: ApprovalLineStepView[];
  // 칸 아래 안내 — 비면 그리지 않는다
  hint?: string | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 결재 진행상태를 가로 순서대로 그린다
 *   2) 문서함·결재 2화면 우측 상세에서 호출한다
 *   3) 단계가 없으면 안내 문구만 남긴다 — 빈 그리드를 두지 않는다
 */
export function ApprovalLineSteps({
  // 결재 단계 칸 — 역할·담당자·결과
  steps,
  // 칸 아래 안내 — 대기 문서 등
  hint,
}: ApprovalLineStepsProps) {
  return (
    <section>
      <div
        // 좌측 목록 헤더와 같은 mes-grid-head — 파란 막대 + 굵은 제목
        className={gridHeadClass}
        role="heading"
        aria-level={3}
      >
        <b>결재 진행상태</b>
      </div>
      {steps.length === 0 ? (
        <p className="mt-2 text-xs text-slate-400">결재선이 없습니다.</p>
      ) : (
        <ol className="mt-3 flex items-start">
          {steps.map((step, at) => {
              const vis = stepperToneClass(step.tone);
              return (
              <li key={step.key} className={`flex min-w-0 ${at === 0 ? "flex-none" : "flex-1"}`}>
                {at > 0 ? (
                  <span
                    // 앞 칸과 잇는 선 — 이 칸의 색과 같게
                    className={`mt-2 h-0.5 flex-1 ${vis.line}`}
                  />
                ) : null}
                <div className="flex w-20 flex-none flex-col items-center">
                  <span className={`h-4 w-4 rounded-full ${vis.dot}`} />
                  <span className={`mt-1 text-xs font-medium ${vis.label}`}>{step.label}</span>
                  {step.caption ? (
                    <span className="mt-0.5 max-w-full truncate text-[10px] text-slate-400">{step.caption}</span>
                  ) : null}
                  {step.detail ? (
                    <span className="mt-0.5 max-w-full text-center text-[10px] leading-tight text-slate-400">{step.detail}</span>
                  ) : null}
                  {step.opinion ? (
                    <span className="mt-0.5 max-w-full text-center text-[10px] leading-tight text-slate-500">{step.opinion}</span>
                  ) : null}
                </div>
              </li>
              );
          })}
        </ol>
      )}
      {steps.length > 0 ? (
        <table
          // 스테퍼 10px 잘림을 보완하는 읽기 표 — 역할·사람·결과·시각·의견
          className="mt-4 w-full border-collapse text-sm"
        >
          <thead>
            <tr className="border-b border-slate-200 text-left text-xs text-slate-500">
              <th className="py-1.5 pr-3 font-medium">역할</th>
              <th className="py-1.5 pr-3 font-medium">사람</th>
              <th className="py-1.5 pr-3 font-medium">결과</th>
              <th className="py-1.5 pr-3 font-medium">시각</th>
              <th className="py-1.5 font-medium">의견</th>
            </tr>
          </thead>
          <tbody>
            {steps.map((step) => (
              <tr key={step.key} className="border-b border-slate-100 align-top">
                <td className="py-1.5 pr-3 text-slate-700">{step.label}</td>
                <td className="py-1.5 pr-3 text-slate-700">{step.caption || "-"}</td>
                <td className="py-1.5 pr-3 text-slate-700">{step.resultNm || "-"}</td>
                <td className="py-1.5 pr-3 tabular-nums text-slate-700">
                  {step.actDisp && step.actDisp !== "-" ? step.actDisp : "-"}
                </td>
                <td className="py-1.5 whitespace-pre-wrap text-slate-600">{step.opinion || "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : null}
      {hint ? (
        <p className="mt-2 text-xs text-slate-400">{hint}</p>
      ) : null}
    </section>
  );
}
