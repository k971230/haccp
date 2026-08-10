/**
 * DocPaper — DB형 HACCP 문서의 종이 서식 영역.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 목업(db형)처럼 흰 용지·제목·결재란·본문 표를 한 덩어리로 감싼다
 *   2) 떠 있는 입력창이 아니라 서식 표 안의 셀 입력을 전제로 한다
 *   3) 저장·결재 API는 소유 화면이 처리하며 이 컴포넌트는 레이아웃만 제공한다
 *
 * PIPELINE[HF120] DB형 문서 용지
 * PIPELINE[HF81, HF83] 연관 모듈
 */
// 역할 — JSX 슬롯
import type { ReactNode } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 작성·검토·승인 결재란
import { DocApprovalStamp } from "./DocApprovalStamp";

export interface DocPaperProps {
  // 문서 제목 — 서식 상단 중앙·좌측에 표시
  title: string;
  // 제목 아래 짧은 안내(한계기준·주기 등)
  subtitle?: string | null;
  // 작성자 표시명 — 결재란 작성칸
  writerNm?: string | null;
  // 검토자 표시명 — 결재란 검토칸
  reviewerNm?: string | null;
  // 승인자 표시명 — 결재란 승인칸
  approverNm?: string | null;
  // 메타 표·본문 표·이탈조치 등 본문 슬롯
  children: ReactNode;
  // 화면별 폭 보정
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 종이 서식 외곽과 결재란을 렌더링한다
 *   2) ColdMonitor·CCP·위생·시설 등 DB형 화면이 공통으로 호출한다
 *   3) 슬롯 데이터는 변경하지 않는다
 */
export function DocPaper({
  // 문서 제목
  title,
  // 한계기준 등 부제
  subtitle,
  // 작성자 스냅샷
  writerNm,
  // 검토자 스냅샷
  reviewerNm,
  // 승인자 스냅샷
  approverNm,
  // 본문
  children,
  // 추가 클래스
  className,
}: DocPaperProps) {
  return (
    <article className={cn("doc-paper", className)} aria-label="문서 본문">
      <header className="doc-paper-head">
        <div className="doc-paper-titles">
          <h2 className="doc-paper-title">{title}</h2>
          {subtitle ? <p className="doc-paper-subtitle">{subtitle}</p> : null}
        </div>
        <DocApprovalStamp
          // 작성 칸 이름 — 없으면 빈 칸
          writerNm={writerNm}
          // 검토 칸 이름
          reviewerNm={reviewerNm}
          // 승인 칸 이름
          approverNm={approverNm}
        />
      </header>
      <div className="doc-paper-body">{children}</div>
    </article>
  );
}
