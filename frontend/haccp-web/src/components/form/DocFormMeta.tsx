/**
 * DocFormMeta — PDF형 문서 상단 메타(작성일·담당·한계·주기·방법).
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 양식모음·CCP 점검표처럼 ○ 라벨이 붙은 한계/주기/방법 칸을 공통으로 그린다
 *   2) 작성일·담당자 등 편집 슬롯과 마스터에서 불러온 읽기전용 문구를 함께 배치한다
 *   3) 문구 저장 API는 호출하지 않는다 — 소유 화면이 마스터·문서 저장을 담당한다
 *
 * PIPELINE[HF123] 문서 메타 표
 * PIPELINE[HF120] 연관 모듈
 */
// 역할 — React 노드
import type { ReactNode } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 메타 표 골격
import { DocMetaTable } from "./DocCell";

export interface DocFormMetaProps {
  // 작성일 셀 — date input 등
  baseDtNode: ReactNode;
  // 담당자·점검자 셀
  managerNode: ReactNode;
  // 담당 라벨 — 기본 담당자
  managerLabel?: string;
  // 한계기준 문구 — 마스터 limitRmk
  limitRmk?: string | null;
  // 주기 문구 — 마스터 cycleRmk
  cycleRmk?: string | null;
  // 방법 문구 — 마스터 methodRmk
  methodRmk?: string | null;
  // CCP 콤보 등 추가 메타 행 (라벨·노드)
  extraRows?: Array<{ label: string; node: ReactNode }>;
  // 한계·주기·방법 표시 여부 — false면 작성일·담당(+extra)만
  showLimitBlock?: boolean;
  // 클래스
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) PDF 상단 메타 표를 조립한다
 *   2) ColdMonitor·Metal·위생·시설 등 DB형 화면에서 호출한다
 *   3) 빈 문구는 대시로 표시한다
 */
export function DocFormMeta({
  // 작성일
  baseDtNode,
  // 담당
  managerNode,
  // 담당 라벨
  managerLabel = "담당자",
  // 한계
  limitRmk,
  // 주기
  cycleRmk,
  // 방법
  methodRmk,
  // 추가 행
  extraRows = [],
  // 한계 블록
  showLimitBlock = true,
  // 클래스
  className,
}: DocFormMetaProps) {
  // 작성일·담당 — 2열
  const topRows = [
    { label: "작성일", node: baseDtNode },
    { label: managerLabel, node: managerNode },
  ];

  return (
    <div className={cn("doc-form-meta space-y-2", className)}>
      <DocMetaTable rows={topRows} pairsPerRow={2} />
      {/* 추가 메타(모니터링 일지 확인 등) — 전폭 1열 SPAN */}
      {extraRows.length > 0 ? (
        <DocMetaTable rows={extraRows} pairsPerRow={1} />
      ) : null}
      {showLimitBlock ? (
        <table className="doc-table doc-meta-table doc-limit-block">
          <tbody>
            <tr>
              <th>한계기준</th>
              <td>
                <span className="doc-meta-bullet">○</span>
                {limitRmk?.trim() || "-"}
              </td>
            </tr>
            <tr>
              <th>주 기</th>
              <td>
                <span className="doc-meta-bullet">○</span>
                <span className="whitespace-pre-wrap">{cycleRmk?.trim() || "-"}</span>
              </td>
            </tr>
            <tr>
              <th>방 법</th>
              <td>
                <span className="doc-meta-bullet">○</span>
                <span className="whitespace-pre-wrap">{methodRmk?.trim() || "-"}</span>
              </td>
            </tr>
          </tbody>
        </table>
      ) : null}
    </div>
  );
}
