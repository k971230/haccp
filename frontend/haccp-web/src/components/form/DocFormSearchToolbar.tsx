/**
 * DocFormSearchToolbar — 문서 조회·명령 공통 헤더.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 시작일·종료일·문서번호·작성자 + 조회/행추가/저장/삭제를 DocForm·문서함·결재함·감사에서 동일하게 쓴다
 *   2) 날짜는 YYYYMMDD 상태로 두고 input[type=date]만 YYYY-MM-DD로 변환한다
 *   3) extraFilters·actions로 화면별 상태/타입/인쇄만 얹고 기본 골격은 유지한다
 *
 * PIPELINE[HF120] 문서 공통 헤더
 * PIPELINE[HF81, HF83, HF85] 연관 모듈
 */
// 역할 — React 노드 슬롯
import type { ReactNode } from "react";
// 역할 — 표준 입력·버튼
import { Input } from "@/components/ui/Input";
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 외곽 section
import { DocFormToolbar } from "@/components/form/DocFormLayout";

/** 공통 검색 조건 — API·세션과 동일 camelCase */
export type DocFormSearchValues = {
  // 시작일 YYYYMMDD
  fromDt: string;
  // 종료일 YYYYMMDD
  toDt: string;
  // 문서번호 부분검색
  docNo: string;
  // 작성자 ID·이름 부분검색
  writer: string;
};

export interface DocFormSearchToolbarProps {
  // 현재 검색 조건
  values: DocFormSearchValues;
  // 조건 부분 갱신
  onChange: (patch: Partial<DocFormSearchValues>) => void;
  // 조회
  onSearch: () => void;
  // 행추가 draft — actions 미지정 시만 사용
  onAdd?: () => void;
  // dirty 저장 — actions 미지정 시만 사용
  onSave?: () => void;
  // 삭제 — actions 미지정 시만 사용
  onDelete?: () => void;
  // 행추가 가능
  canAdd?: boolean;
  // 저장 가능 (보통 true — 검증은 핸들러)
  canSave?: boolean;
  // 삭제 가능
  canDelete?: boolean;
  // 조회 busy
  searchBusy?: boolean;
  // 저장·삭제·행추가 busy
  actionBusy?: boolean;
  // 작성자 뒤·조회 앞 추가 필터 (상태·타입 등)
  extraFilters?: ReactNode;
  // 우측 액션 전체 교체 — 지정 시 행추가/저장/삭제 대신 렌더
  actions?: ReactNode;
  // 기본 CRUD 버튼 노출 — false면 조회만 (actions 없을 때)
  showCrudActions?: boolean;
}

/** YYYYMMDD → YYYY-MM-DD */
function toInput(ymd: string): string {
  return ymd?.length === 8 ? `${ymd.slice(0, 4)}-${ymd.slice(4, 6)}-${ymd.slice(6, 8)}` : "";
}

/** YYYY-MM-DD → YYYYMMDD */
function fromInput(value: string): string {
  return (value || "").replace(/-/g, "");
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 공통 조회 헤더를 렌더링한다
 *   2) Cold·Metal·Generic·위생·BizOps DocForm 화면이 호출한다
 *   3) 슬롯 값은 변경하지 않는다
 */
export function DocFormSearchToolbar({
  // 검색 조건
  values,
  // 조건 변경
  onChange,
  // 조회
  onSearch,
  // 행추가
  onAdd,
  // 저장
  onSave,
  // 삭제
  onDelete,
  // 행추가 권한
  canAdd = true,
  // 저장 가능
  canSave = true,
  // 삭제 가능
  canDelete = false,
  // 조회 busy
  searchBusy = false,
  // 액션 busy
  actionBusy = false,
  // 추가 필터 슬롯
  extraFilters,
  // 우측 액션 슬롯
  actions,
  // 기본 CRUD 노출
  showCrudActions = true,
}: DocFormSearchToolbarProps) {
  return (
    <DocFormToolbar>
      <label className="flex flex-col gap-1 text-xs text-slate-600">
        {/* 목록 기준일 하한 */}
        시작일
        <Input
          type="date"
          className="w-36"
          value={toInput(values.fromDt)}
          onChange={(e) => onChange({ fromDt: fromInput(e.target.value) })}
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-600">
        {/* 목록 기준일 상한 */}
        종료일
        <Input
          type="date"
          className="w-36"
          value={toInput(values.toDt)}
          onChange={(e) => onChange({ toDt: fromInput(e.target.value) })}
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-600">
        {/* 문서번호 부분검색 — SP ILIKE */}
        문서번호
        <Input
          className="w-40"
          value={values.docNo}
          placeholder="문서번호"
          onChange={(e) => onChange({ docNo: e.target.value })}
          onKeyDown={(e) => { if (e.key === "Enter") onSearch(); }}
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-600">
        {/* 작성자 ID·이름 부분검색 */}
        작성자
        <Input
          className="w-36"
          value={values.writer}
          placeholder="ID 또는 이름"
          onChange={(e) => onChange({ writer: e.target.value })}
          onKeyDown={(e) => { if (e.key === "Enter") onSearch(); }}
        />
      </label>
      {/* 화면별 상태·타입 등 — 공통 4필드 뒤에만 붙인다 */}
      {extraFilters}
      <MesButton
        // 목록 재조회
        variant="search"
        icon="search"
        disabled={searchBusy || actionBusy}
        onClick={onSearch}
      >
        조회
      </MesButton>
      {(actions != null || showCrudActions) ? (
        <div className="ml-auto flex flex-wrap gap-2">
          {actions != null ? actions : (
            <>
              <MesButton
                // 좌측 draft 행추가
                variant="add"
                disabled={!canAdd || actionBusy}
                onClick={() => onAdd?.()}
              >
                행추가
              </MesButton>
              <MesButton
                // dirty 전건 저장
                variant="save"
                disabled={!canSave || actionBusy}
                onClick={() => onSave?.()}
              >
                저장
              </MesButton>
              <MesButton
                // draft 제거 또는 서버 삭제
                variant="danger"
                disabled={!canDelete || actionBusy}
                onClick={() => onDelete?.()}
              >
                삭제
              </MesButton>
            </>
          )}
        </div>
      ) : null}
    </DocFormToolbar>
  );
}

/** 기본 검색 기간 — 당월 1일~오늘 */
export function defaultDocFormSearch(): DocFormSearchValues {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return {
    fromDt: `${y}${m}01`,
    toDt: `${y}${m}${d}`,
    docNo: "",
    writer: "",
  };
}
