/**
 * HwpTemplateFileHistModal — 사용양식 파일 이력 불러오기 팝업.
 *
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 코드조회와 같은 셸 — 보라 헤더·검색행·MesDataGrid·푸터. 사용양식만 쓰므로 공통 모달에 넣지 않는다
 *   2) 라디오 1건 + 행 클릭으로 고르고, 적용은 푸터에서 확정한다
 *   3) 목록 API는 호출하지 않는다 — 호출 화면이 이력을 넘기고 파일명·src-ty 만 거른다
 *
 * PIPELINE[HF123] 사용양식 파일 이력 팝업
 */
// 역할 — 검색 draft/applied·컬럼 메모
import { useEffect, useMemo, useState } from "react";
// 역할 — 읽기전용 그리드 — 라디오 단건
import { MesDataGrid } from "@/components/grid/MesDataGrid";
// 역할 — 조회·취소·적용
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 검색 input·select 공통 스타일
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 보라 그리드 헤더 높이·색
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 공통 모달 본문 높이 280
import { COMMON_MODAL_BODY_H } from "@/components/common/modal/modalTypes";
// 역할 — 파일 이력 출처 공통코드 src-ty
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 파일 이력 행 타입
import type { HwpTemplateFile } from "@/api/hwp/hwpTemplateApi";
// 역할 — 팝업 그리드 pref 키·컬럼·src-ty 대분류
import {
  FILE_HIST_PERSIST_ID,
  SCRN_CD,
  SRC_TY_MAIN_CD,
  buildFileHistColumns,
} from "./HwpTemplateManagementRule";

export type HwpTemplateFileHistModalProps = {
  // true면 오버레이를 그린다
  open: boolean;
  // 파일 이력 행 — 현재 적용본·기본 제공본 포함
  rows: HwpTemplateFile[];
  // 라디오로 고른 파일 idx
  activeIdx: number | null;
  // 적용 API 진행 중
  applying: boolean;
  // 행·라디오 클릭 — idx만 올린다
  onSelect: (idx: number) => void;
  // 푸터 적용 — 호출 화면이 mesConfirm·API를 담당
  onApply: () => void;
  // 배경·취소
  onClose: () => void;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 이력 그리드에서 1건을 고른 뒤 적용한다
 *   2) 미리보기 헤더 「불러오기」가 연다
 *   3) 적용 실패는 호출 화면이 mesError로 안내한다
 */
export function HwpTemplateFileHistModal({
  open,
  rows,
  activeIdx,
  applying,
  onSelect,
  onApply,
  onClose,
}: HwpTemplateFileHistModalProps) {
  // 역할 — src-ty 콤보·양식구분 열 라벨
  const srcTy = useCommonCodes(SRC_TY_MAIN_CD);
  // 입력 중 파일명 — 조회 전
  const [draftNm, setDraftNm] = useState("");
  // 입력 중 구분 — 빈 값=전체
  const [draftSrc, setDraftSrc] = useState("");
  // 확정 파일명
  const [appliedNm, setAppliedNm] = useState("");
  // 확정 구분
  const [appliedSrc, setAppliedSrc] = useState("");

  const columns = useMemo(
    () => buildFileHistColumns(srcTy.codeMap),
    [srcTy.codeMap],
  );

  const runSearch = () => {
    setAppliedNm(draftNm.trim());
    setAppliedSrc(draftSrc);
  };

  const filteredRows = useMemo(() => {
    const nq = appliedNm.toLowerCase();
    // 검색어·구분 없을 때(= 전체) 필터 생략
    if (!nq && !appliedSrc) return rows;
    return rows.filter((file) => {
      // 파일명 칸 — 부분일치 (빈 칸이면 통과)
      const nameOk = !nq || String(file.fileNm ?? "").toLowerCase().includes(nq);
      // 구분 칸 — srcTy 일치 (빈 값이면 통과)
      const srcOk = !appliedSrc || file.srcTy === appliedSrc;
      return nameOk && srcOk;
    });
  }, [appliedNm, appliedSrc, rows]);

  useEffect(() => {
    // 다시 열릴 때(= 이전 검색 잔여) 조건을 비운다
    if (!open) return;
    setDraftNm("");
    setDraftSrc("");
    setAppliedNm("");
    setAppliedSrc("");
  }, [open]);

  if (!open) return null;

  return (
    <div
      // 파일 이력 모달 오버레이 — 배경 클릭 시 닫기
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label="양식 파일 불러오기"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        // 코드조회보다 넓게 — 파일명·등록일 열이 한 줄에 붙지 않게
        className="flex w-full max-w-2xl flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div
          // 코드조회·서명과 동일 — 보라 accent mes-grid-head
          className={cn(gridHeadClass, "mes-modal-grid-head")}
        >
          <b>양식 파일 불러오기</b>
        </div>
        <div className="flex flex-col gap-2 p-3">
          <div
            // 파일명·양식구분 이중 검색 + 조회 — 코드조회와 같은 한 줄
            className="flex flex-wrap items-center gap-1.5"
          >
            <input
              // 파일명 부분검색
              className={cn(searchInputClass, "h-8 min-w-0 flex-1 bg-white")}
              placeholder="파일명"
              value={draftNm}
              onChange={(e) => setDraftNm(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  runSearch();
                }
              }}
              autoFocus
            />
            <select
              // 양식구분 — src-ty. 빈 값=전체
              className={cn(searchInputClass, "h-8 w-[8.5rem] bg-white")}
              value={draftSrc}
              onChange={(e) => setDraftSrc(e.target.value)}
            >
              <option value="">전체</option>
              {srcTy.codes.map((code) => (
                <option
                  key={code.subCd}
                  value={code.subCd}
                >
                  {code.codeNm}
                </option>
              ))}
            </select>
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
            // 불러오기 팝업 그리드 — 열 설정 저장 키
            persistId={FILE_HIST_PERSIST_ID}
            // pref 저장용 화면코드 — 사용양식관리와 동일
            scrnCd={SCRN_CD}
            // 파일명·양식구분 필터된 이력
            rows={filteredRows}
            // 파일명·등록일·양식구분·현재적용
            columns={columns}
            // 이력 PK — idx
            rowKey={(r) => String(r.idx)}
            // 라디오·행 강조 — 고른 파일 idx
            activeKey={activeIdx == null ? null : String(activeIdx)}
            // 단건 라디오 — 다중 체크박스 아님
            singleSelect
            // 결과 내 검색·필터·열
            showToolbar
            // 건수 푸터
            showFooter
            // 행번호 생략 — 라디오가 리드 열
            showRowNum={false}
            // 정렬 허용
            sortable
            // 코드조회·서명과 동일 높이
            height={COMMON_MODAL_BODY_H}
            title="양식 파일 불러오기"
            // 행 클릭 — 적용 전 선택만
            onRowClick={(r) => onSelect(r.idx)}
          />
        </div>
        <div
          // 공통 모달 푸터 — 취소·적용 우측
          className="flex shrink-0 items-center justify-end gap-2 border-t border-slate-200 bg-slate-50/70 px-3 py-2.5"
        >
          <MesButton
            // 선택 없이 닫기
            variant="secondary"
            onClick={onClose}
          >
            취소
          </MesButton>
          <MesButton
            // 고른 버전을 현재 적용본으로
            variant="save"
            loading={applying}
            onClick={onApply}
          >
            적용
          </MesButton>
        </div>
      </div>
    </div>
  );
}
