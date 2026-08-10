/**
 * DocFormLayout — DB형 HACCP 문서의 조회·목록·용지·요약 영역을 고정 배치한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 목업(db형)처럼 목록·문서 용지·우측 요약을 한 화면에 배치한다
 *   2) DB형 양식이 같은 외곽을 써 화면 전환 때 위치가 달라지지 않게 한다
 *   3) 조회·저장 API는 소유 화면에 남긴다
 *
 * PIPELINE[HF119] DB형 문서 레이아웃
 * PIPELINE[HF120, HF81] 연관 모듈
 */
// 역할 — JSX 슬롯·CSS 클래스 타입
import type { ReactNode } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — SoPage형 그리드 패널 헤더(보이는 그리드명)
import { gridHeadClass } from "@/components/layout/pageClasses";

export interface DocFormLayoutProps {
  // 조회 영역과 문서 패널 조합을 담는 화면 슬롯
  children: ReactNode;
  // 화면별 보완이 필요한 레이아웃 클래스
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) DB형 문서 화면 외곽을 렌더링한다
 *   2) 모든 DB형 작성 화면이 호출한다
 *   3) 슬롯 데이터는 변경하지 않는다
 */
export function DocFormLayout({
  // 화면 슬롯
  children,
  // 추가 클래스
  className,
}: DocFormLayoutProps) {
  return (
    <div className={cn("flex h-full min-h-0 flex-col gap-3 p-3", className)}>
      {children}
    </div>
  );
}

/** 조회 조건과 문서 명령을 담는 상단 영역 props */
export interface DocFormToolbarProps {
  // 날짜 조건·조회·신규·저장·삭제·결재 버튼 JSX
  children: ReactNode;
}

/** DB형 문서의 조회 조건과 명령을 표시한다. */
export function DocFormToolbar({ children }: DocFormToolbarProps) {
  return (
    <section aria-label="문서 조회 및 명령" className="flex flex-wrap items-end gap-2 rounded border border-slate-200 bg-white p-3">
      {children}
    </section>
  );
}

/** 목록·용지·요약을 분할 배치하는 본문 props */
export interface DocFormBodyProps {
  // 문서 목록·용지·요약 패널 JSX
  children: ReactNode;
  // 우측 요약 패널 포함 여부 — 기본 true(목록|용지|요약)
  withSummary?: boolean;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 작성 화면 전용 — 좌측 문서목록 | 중앙 용지/에디터 | (옵션) 우측 요약
 *   2) 문서함(inbox)에는 쓰지 않는다 — 문서함은 전체폭 목록이다
 *   3) lg 이상에서 좌측 목록이 보이도록 한다 (xl만 쓰면 노트북에서 위로 쌓임)
 */
export function DocFormBody({
  // 자식 패널 — 첫 자식=좌측 목록(DocFormDocumentList)
  children,
  // 요약 열 사용
  withSummary = true,
}: DocFormBodyProps) {
  return (
    <div
      className={cn(
        "grid min-h-0 flex-1 grid-cols-1 gap-3",
        withSummary
          ? "lg:grid-cols-[minmax(14rem,20%)_minmax(0,1fr)_minmax(12rem,16%)]"
          : "lg:grid-cols-[minmax(16rem,22%)_minmax(0,1fr)]"
      )}
    >
      {children}
    </div>
  );
}

/** 왼쪽 문서 목록 패널 props */
export interface DocFormDocumentListProps {
  // 목록 테이블 또는 빈 결과 메시지 JSX
  children: ReactNode;
  // 목록 landmark 이름
  label?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 좌측 문서 목록 패널에 보이는 그리드명(header)과 목록 슬롯을 렌더한다
 *   2) Hygiene·CCP·HWP 등 DocForm 작성 화면이 공통으로 호출한다
 *   3) label은 aria와 헤더 `<b>`에 동일하게 쓴다 — MesEditableGrid title과 맞출 것
 */
export function DocFormDocumentList({ children, label = "문서 목록" }: DocFormDocumentListProps) {
  return (
    <aside
      aria-label={label}
      // MesEditableGrid height=100% 채움용 flex 체인 — 헤더는 shrink-0
      className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-200 bg-white p-1"
    >
      <div className={gridHeadClass}>
        {/* 보이는 그리드명 — SoPage gridHead와 동일 슬롯 */}
        <b>{label}</b>
      </div>
      {children}
    </aside>
  );
}

/** 가운데 문서 용지 패널 props */
export interface DocFormMainPanelProps {
  // DocPaper 등 문서 본문 JSX
  children: ReactNode;
}

/** 선택한 문서를 작성·검토하는 용지 패널을 렌더링한다. */
export function DocFormMainPanel({ children }: DocFormMainPanelProps) {
  return (
    <main aria-label="문서 작성 폼" className="min-h-0 overflow-auto rounded border border-slate-200 bg-slate-100/70 p-3">
      {children}
    </main>
  );
}

/** 우측 요약·필수입력 패널 props */
export interface DocFormSidePanelProps {
  // DocSummaryPanel 등
  children: ReactNode;
  // landmark 이름
  label?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 우측 요약 패널에 보이는 제목과 본문 슬롯을 렌더한다
 *   2) DocForm 작성 화면의 요약·필수입력 열이 호출한다
 *   3) label은 aria와 헤더 `<b>`에 동일하게 쓴다
 */
export function DocFormSidePanel({ children, label = "문서 요약" }: DocFormSidePanelProps) {
  return (
    <aside
      aria-label={label}
      className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-200 bg-white p-1"
    >
      <div className={gridHeadClass}>
        {/* 보이는 패널명 — 문서 목록 헤더와 동일 밀도 */}
        <b>{label}</b>
      </div>
      <div className="min-h-0 flex-1 overflow-auto p-2">
        {children}
      </div>
    </aside>
  );
}
