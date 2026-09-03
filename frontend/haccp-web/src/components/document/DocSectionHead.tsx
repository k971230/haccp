/**
 * DocSectionHead — 결재 상세 우측 섹션 제목.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 좌측 목록 헤더와 같은 파란 배지(mes-grid-head)로 섹션 제목을 그린다
 *   2) 결재첨부·문서함·결재대기·결재완료가 같이 쓴다. 화면마다 복제하지 않는다
 *   3) 반려·취소만 danger — 파란 막대를 빨강으로 바꾼다
 *
 * PIPELINE[HF185] 결재 첨부 화면
 * PIPELINE[HF83] 문서함 화면
 */
// 역할 — 자식 노드
import type { ReactNode } from "react";
// 역할 — 그리드 헤더와 같은 파란 막대
import { gridHeadClass } from "@/components/layout/pageClasses";

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 우측 섹션 제목을 좌측 목록과 같은 파란 배지로 그린다
 *   2) 진행상태·원본·첨부·비고·반려/취소 사유가 호출한다
 *   3) extra 는 첨부 개수·파일 추가 버튼처럼 제목 오른쪽에 둔다
 */
export function DocSectionHead({
  // 섹션 제목
  title,
  // true 면 빨간 막대 — 반려·취소 사유
  danger,
  // 제목 오른쪽 보조 (개수·버튼)
  extra,
}: {
  title: string;
  danger?: boolean;
  extra?: ReactNode;
}) {
  return (
    <div
      // 좌측 목록 헤더와 같은 mes-grid-head — 파란 막대 + 굵은 제목
      className={gridHeadClass}
      role="heading"
      aria-level={3}
    >
      <b className={danger ? "[&::before]:!bg-red-600" : undefined}>{title}</b>
      {extra}
    </div>
  );
}
