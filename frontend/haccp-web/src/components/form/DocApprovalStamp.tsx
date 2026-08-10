/**
 * DocApprovalStamp — 작성·검토·승인 결재란.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 종이 HACCP 서식의 우측 상단 결재 도장란을 HTML 표로 재현한다
 *   2) 이름은 문서 헤더 스냅샷이며 여기서 결재를 처리하지 않는다
 *   3) 값이 없으면 빈 칸을 유지해 미결재 상태를 표현한다
 *
 * PIPELINE[HF121] 결재란
 * PIPELINE[HF120] 연관 모듈
 */
// 역할 — className 병합
import { cn } from "@/lib/cn";

export interface DocApprovalStampProps {
  // 작성자 표시명
  writerNm?: string | null;
  // 검토자 표시명
  reviewerNm?: string | null;
  // 승인자 표시명
  approverNm?: string | null;
  // 추가 클래스
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 3칸 결재란을 렌더링한다
 *   2) DocPaper 헤더가 호출한다
 *   3) 결재 API를 호출하지 않는다
 */
export function DocApprovalStamp({
  // 작성자
  writerNm,
  // 검토자
  reviewerNm,
  // 승인자
  approverNm,
  // 클래스
  className,
}: DocApprovalStampProps) {
  const cells = [
    { role: "작성", name: writerNm },
    { role: "검토", name: reviewerNm },
    { role: "승인", name: approverNm },
  ];
  return (
    <table className={cn("doc-stamp", className)} aria-label="결재란">
      <thead>
        <tr>
          {cells.map((cell) => (
            <th key={cell.role}>{cell.role}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        <tr>
          {cells.map((cell) => (
            <td key={cell.role}>
              <span className="doc-stamp-name">{cell.name || ""}</span>
            </td>
          ))}
        </tr>
      </tbody>
    </table>
  );
}
