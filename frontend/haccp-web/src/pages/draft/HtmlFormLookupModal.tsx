/**
 * HtmlFormLookupModal — 양식 작성 공통 양식 선택 팝업 (일자·양식코드·양식명).
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 좌측 작성 행의 양식코드 버튼에서 연다. 공통 CodeLookupModal 은 코드·코드명 2열이라 일자 칸을 못 넣는다
 *   2) 셸·검색·그리드·푸터는 CodeLookupModal 과 같은 클래스를 쓴다 — 팝업 생김새를 화면마다 다르게 두지 않는다
 *   3) HYG·CCP 작성 화면이 같이 쓴다. 양식 작성 도메인 전용이라 components/common/modal 로 올리지 않는다
 *
 * 목록 API 는 호출하지 않는다. 화면이 진입 시 읽어 둔 사용 가능 양식을 그대로 받는다.
 *
 * PIPELINE[HF174] 양식 선택 팝업
 */
// 역할 — 검색어 상태·필터 메모
import { useMemo, useState } from "react";
// 역할 — 조회 전용 그리드
import { MesDataGrid } from "@/components/grid/MesDataGrid";
// 역할 — 표준 버튼·검색 입력 스타일
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 팝업 헤더(보라 accent)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 공통 모달 바디 높이 — 코드 룩업·서명 팝업과 같은 크기
import { COMMON_MODAL_BODY_H } from "@/components/common/modal/modalTypes";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 작성 가능 양식 행 (HYG·CCP 공통)
import type { HtmlFormDraftForm } from "@/api/draft/htmlFormDraftTypes";

/** 팝업 그리드 행 — 일자·양식코드·양식명 3열 */
type FormLookupRow = {
  // 양식 등록일자 YYYY-MM-DD
  insDt: string;
  // 양식코드 html_hyg_prc_NNN
  tmplCd: string;
  // 양식명
  tmplNm: string;
};

export interface HtmlFormLookupModalProps {
  // 팝업 제목
  title?: string;
  // 그리드 열 설정 pref 화면코드 — 호출 화면의 scrnCd
  scrnCd: string;
  // 고를 수 있는 양식 — 사용여부 예인 자사 양식만 넘어온다
  forms: HtmlFormDraftForm[];
  // 현재 선택된 양식코드 — 행 강조
  value?: string;
  // 선택 확정 — 양식코드·양식명을 작성 행에 반영한다
  onSelect: (tmplCd: string, tmplNm: string) => void;
  // 선택 없이 닫기
  onClose: () => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 사용 가능 양식을 일자·양식코드·양식명 3열로 보여 주고 1건을 고른다
 *   2) 좌측 작성 행의 양식코드 셀 버튼이 연다
 *   3) 행을 클릭하면 즉시 확정하고 팝업을 닫는다
 */
export function HtmlFormLookupModal({
  title = "양식 선택",
  scrnCd,
  forms,
  value,
  onSelect,
  onClose,
}: HtmlFormLookupModalProps) {
  // 입력 중 양식코드 검색어 — Enter·조회 전
  const [draftCode, setDraftCode] = useState("");
  // 입력 중 양식명 검색어
  const [draftName, setDraftName] = useState("");
  // 확정 양식코드 검색어 — 목록 필터
  const [appliedCode, setAppliedCode] = useState("");
  // 확정 양식명 검색어
  const [appliedName, setAppliedName] = useState("");

  const runSearch = () => {
    setAppliedCode(draftCode.trim());
    setAppliedName(draftName.trim());
  };

  const rows = useMemo((): FormLookupRow[] => {
    const mapped = forms.map((f) => ({
      insDt: f.insDt ?? "",
      tmplCd: f.tmplCd,
      tmplNm: f.verNm,
    }));
    const cq = appliedCode.toLowerCase();
    const nq = appliedName.toLowerCase();
    // 검색어가 없을 때(= 전체) 필터를 생략한다
    if (!cq && !nq) return mapped;
    return mapped.filter((row) => {
      const codeOk = !cq || row.tmplCd.toLowerCase().includes(cq);
      const nameOk = !nq || row.tmplNm.toLowerCase().includes(nq);
      return codeOk && nameOk;
    });
  }, [appliedCode, appliedName, forms]);

  const columns = useMemo(
    (): GridColumn<FormLookupRow>[] => [
      {
        // 일자 — 양식 등록일자. 요구 컬럼 순서대로 맨 앞
        field: "insDt",
        header: "일자",
        width: 110,
        type: "date",
      },
      {
        // 양식코드 — 선택 시 작성 행에 반영
        field: "tmplCd",
        header: "양식코드",
        width: 150,
      },
      {
        // 양식명 — 선택 시 작성 행에 함께 반영
        field: "tmplNm",
        header: "양식명",
        width: 180,
      },
    ],
    [],
  );

  const pick = (row: FormLookupRow) => {
    onSelect(row.tmplCd, row.tmplNm);
    onClose();
  };

  return (
    <div
      // 양식 선택 팝업 오버레이 — 배경 클릭 시 닫기
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="flex w-full max-w-lg flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div
          // 코드 룩업·서명 팝업과 동일 — 보라 accent mes-grid-head
          className={cn(gridHeadClass, "mes-modal-grid-head")}
        >
          <b>{title}</b>
        </div>
        <div className="flex flex-col gap-2 p-3">
          <div
            // 양식코드·양식명 이중 검색 + 조회
            className="flex flex-wrap items-center gap-1.5"
          >
            <input
              // 양식코드 부분검색 — 팝업 안 로컬 필터
              className={cn(searchInputClass, "h-8 w-[8.5rem] bg-white")}
              placeholder="양식코드"
              value={draftCode}
              onChange={(e) => setDraftCode(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  runSearch();
                }
              }}
              autoFocus
            />
            <input
              // 양식명 부분검색
              className={cn(searchInputClass, "h-8 min-w-0 flex-1 bg-white")}
              placeholder="양식명"
              value={draftName}
              onChange={(e) => setDraftName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  runSearch();
                }
              }}
            />
            <MesButton
              // Enter 와 동일 — applied 검색어 확정
              size="sm"
              variant="search"
              onClick={runSearch}
            >
              조회
            </MesButton>
          </div>
          <MesDataGrid
            // 양식 선택 팝업 그리드 — 열 설정 저장 키 (HYG·CCP 공통)
            persistId="html-form-draft-lookup"
            // pref 저장용 화면코드 — 호출부 hyg-process / ccp-verify
            scrnCd={scrnCd}
            // 필터된 사용 가능 양식
            rows={rows}
            // 일자·양식코드·양식명
            columns={columns}
            // 양식코드가 행 키
            rowKey={(r) => r.tmplCd}
            // 현재 작성 행의 양식 강조
            activeKey={value ?? null}
            // 결과 내 검색·필터·열 너비 pref
            showToolbar
            // 건수 푸터
            showFooter
            // 행번호 생략 — 코드 룩업과 동일
            showRowNum={false}
            sortable
            // 공통 모달 바디 높이
            height={COMMON_MODAL_BODY_H}
            title={title}
            // 행 클릭 — 양식코드·양식명 확정 후 닫기
            onRowClick={pick}
          />
        </div>
        <div
          // 공통 모달 푸터 — 닫기 우측 끝
          className="flex shrink-0 items-center justify-end gap-2 border-t border-slate-200 bg-slate-50/70 px-3 py-2.5"
        >
          <MesButton
            // 선택 없이 닫기
            variant="secondary"
            onClick={onClose}
          >
            닫기
          </MesButton>
        </div>
      </div>
    </div>
  );
}
