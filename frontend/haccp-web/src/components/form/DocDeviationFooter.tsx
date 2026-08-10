/**
 * DocDeviationFooter — PDF 고정 이탈·개선조치 푸터.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 이탈내용·개선조치 및 결과·조치자·확인 4칸 레이아웃을 모든 DB형 일지에 공통 제공한다
 *   2) 레이아웃은 고정이고 값만 소유 화면 state·CA 저장으로 유지한다
 *   3) 빈 값은 저장 시 CA 행 삭제로 처리한다
 *
 * PIPELINE[HF124] 문서 이탈 푸터
 * PIPELINE[HF120] 연관 모듈
 */
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 셀 입력
import { DocCellInput } from "./DocCell";

/** 푸터 값 — tbl_corrective_action 문서 단위 1건 */
export interface DocCorrectiveValue {
  // 이탈내용
  deviationDesc?: string | null;
  // 개선조치 및 결과
  actionDesc?: string | null;
  // 조치자 표시명
  actionUserNm?: string | null;
  // 확인자 표시명
  confirmUserNm?: string | null;
}

export interface DocDeviationFooterProps {
  // 현재 값
  value: DocCorrectiveValue;
  // 변경 — 부분 패치
  onChange: (next: DocCorrectiveValue) => void;
  // 편집 가능
  editable?: boolean;
  // 클래스
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 푸터 4칸 표를 렌더링한다
 *   2) DocPaper 본문 표 아래에서 호출한다
 *   3) 읽기 전용이면 textarea·input을 disabled 한다
 */
export function DocDeviationFooter({
  // 값
  value,
  // 변경
  onChange,
  // 편집
  editable = true,
  // 클래스
  className,
}: DocDeviationFooterProps) {
  const patch = (key: keyof DocCorrectiveValue, next: string) =>
    onChange({ ...value, [key]: next });

  return (
    <div className={cn("doc-deviation-footer", className)}>
      <p className="doc-section-title">이탈·개선조치</p>
      <table className="doc-table doc-footer-table">
        <thead>
          <tr>
            <th>이탈내용</th>
            <th>개선조치 및 결과</th>
            <th className="doc-footer-narrow">조치자</th>
            <th className="doc-footer-narrow">확인</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>
              <textarea
                className="doc-note-area"
                disabled={!editable}
                value={value.deviationDesc ?? ""}
                onChange={(e) => patch("deviationDesc", e.target.value)}
                rows={3}
              />
            </td>
            <td>
              <textarea
                className="doc-note-area"
                disabled={!editable}
                value={value.actionDesc ?? ""}
                onChange={(e) => patch("actionDesc", e.target.value)}
                rows={3}
              />
            </td>
            <td className="doc-footer-narrow">
              <DocCellInput
                value={value.actionUserNm ?? ""}
                disabled={!editable}
                onChange={(v) => patch("actionUserNm", v)}
              />
            </td>
            <td className="doc-footer-narrow">
              <DocCellInput
                value={value.confirmUserNm ?? ""}
                disabled={!editable}
                onChange={(v) => patch("confirmUserNm", v)}
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}

/** 푸터 네 칸이 모두 비었는지 — 저장 시 CA 삭제 판단 */
export function isCorrectiveEmpty(value: DocCorrectiveValue | null | undefined): boolean {
  if (!value) return true;
  return ![value.deviationDesc, value.actionDesc, value.actionUserNm, value.confirmUserNm]
    .some((v) => String(v ?? "").trim() !== "");
}
