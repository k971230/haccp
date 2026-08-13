/**
 * CodeLookupModal — 권한그룹·부서 등 코드 선택 공통 팝업.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) pages/sys/CodeLookupDialog에서 옮겨온 전역 모달 — 어느 도메인에서든 openModal("CodeLookup", ...)로 연다
 *   2) 서명 팝업과 동일 셸 — 보라 mes-grid-head·max-w-lg·280 바디·푸터 닫기 우측
 *   3) 열림 여부는 modalStore가 관리하므로 이 컴포넌트는 열렸을 때만 마운트된다
 *
 * PIPELINE[HF99] 코드 조회 팝업
 */
import { useMemo, useState } from "react";
import { MesDataGrid } from "@/components/grid/MesDataGrid";
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
import { gridHeadClass } from "@/components/layout/pageClasses";
import { cn } from "@/lib/cn";
import type { GridColumn } from "@/types/grid";
// 역할 — 모달 종류별 props 계약·공통 바디 높이
import { COMMON_MODAL_BODY_H, type CodeLookupModalProps } from "./modalTypes";
// 역할 — 전역 모달 닫기
import { useModalStore } from "@/stores/modalStore";

/** 그리드 행 — 빈 코드도 rowKey를 가질 수 있게 _key를 붙인다 */
type LookupRow = { value: string; label: string; _key: string };

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 코드 선택 UI를 MesDataGrid로 렌더한다
 *   2) 사용자·부서 관리 등 셀 버튼에서 연다
 *   3) 선택·닫기만 하며 목록 API는 호출하지 않는다 — 목록은 호출 화면이 넘긴다
 */
export function CodeLookupModal({
  // 모달 제목 — 권한그룹·부서·상위부서 (보라 배지)
  title,
  // 그리드 pref 화면코드 — 호출부 scrnCd (없으면 열 상태 미저장)
  scrnCd,
  // 선택 가능 목록 — value=코드, label=표시명
  options,
  // 현재 선택 코드
  value,
  // true면 (없음) 행으로 빈 코드 선택
  allowEmpty = false,
  // 코드·표시명 확정 — 빈 선택이면 label=""
  onSelect,
}: CodeLookupModalProps) {
  // 역할 — 배경·닫기 버튼·선택 확정 후 모달 종료
  const closeModal = useModalStore((s) => s.closeModal);
  // 입력 중 코드 검색어 — Enter·조회 전
  const [draftCode, setDraftCode] = useState("");
  // 입력 중 코드명 검색어
  const [draftName, setDraftName] = useState("");
  // 확정 코드 검색어 — 목록 필터
  const [appliedCode, setAppliedCode] = useState("");
  // 확정 코드명 검색어
  const [appliedName, setAppliedName] = useState("");

  const runSearch = () => {
    setAppliedCode(draftCode.trim());
    setAppliedName(draftName.trim());
  };

  const rows = useMemo((): LookupRow[] => {
    const base = allowEmpty ? [{ value: "", label: "(없음)" }, ...options] : options;
    const mapped = base.map((o) => ({
      ...o,
      // 빈 코드 행 키 — MesDataGrid rowKey 안정용
      _key: o.value ? o.value : "__empty__",
    }));
    const cq = appliedCode.toLowerCase();
    const nq = appliedName.toLowerCase();
    // 검색어 없을 때(= 전체) 필터 생략
    if (!cq && !nq) return mapped;
    return mapped.filter((o) => {
      // 코드 칸 — value 부분일치 (빈 칸이면 통과)
      const codeOk = !cq || o.value.toLowerCase().includes(cq);
      // 명 칸 — label 부분일치
      const nameOk = !nq || o.label.toLowerCase().includes(nq);
      return codeOk && nameOk;
    });
  }, [allowEmpty, appliedCode, appliedName, options]);

  const columns = useMemo(
    (): GridColumn<LookupRow>[] => [
      {
        // 코드 열
        field: "value",
        header: "코드",
        width: 120,
      },
      {
        // 코드명 열 — 권한그룹명·부서명 등
        field: "label",
        header: "코드명",
        width: 200,
      },
    ],
    [],
  );

  const pick = (row: LookupRow) => {
    // (없음) 행일 때(= 빈 코드) 표시명은 비운다
    const label = row.value ? row.label : "";
    onSelect(row.value, label);
    closeModal();
  };

  const activeKey = value ? value : allowEmpty && value === "" ? "__empty__" : null;

  return (
    <div
      // 코드 선택 모달 오버레이 — 배경 클릭 시 닫기
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) closeModal();
      }}
    >
      <div
        className="flex w-full max-w-lg flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div
          // 서명 팝업과 동일 — 보라 accent mes-grid-head
          className={cn(gridHeadClass, "mes-modal-grid-head")}
        >
          <b>{title}</b>
        </div>
        <div className="flex flex-col gap-2 p-3">
          <div
            // 코드·코드명 이중 검색 + 조회
            className="flex flex-wrap items-center gap-1.5"
          >
            <input
              // 코드 부분검색
              className={cn(searchInputClass, "h-8 w-[8.5rem] bg-white")}
              placeholder="코드"
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
              // 코드명 부분검색
              className={cn(searchInputClass, "h-8 min-w-0 flex-1 bg-white")}
              placeholder="코드명"
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
              // Enter와 동일 — applied 검색어 확정
              size="sm"
              variant="search"
              onClick={runSearch}
            >
              조회
            </MesButton>
          </div>
          <MesDataGrid
            // 코드 조회 팝업 그리드 — 열 설정 저장 키
            persistId="code-lookup-dialog"
            // pref 저장용 화면코드 — 호출부 department/user-management
            scrnCd={scrnCd}
            // 필터된 코드·코드명 목록
            rows={rows}
            columns={columns}
            // 빈 코드는 __empty__
            rowKey={(r) => r._key}
            // 현재 선택 행 강조
            activeKey={activeKey}
            // 결과 내 검색·필터·열 — 열 너비 pref 포함
            showToolbar
            // 건수 푸터
            showFooter
            // 행번호 생략
            showRowNum={false}
            // 정렬 허용
            sortable
            // 서명 미리보기와 동일 높이
            height={COMMON_MODAL_BODY_H}
            title={title}
            // 행 클릭 — 코드·명 확정
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
            onClick={closeModal}
          >
            닫기
          </MesButton>
        </div>
      </div>
    </div>
  );
}
