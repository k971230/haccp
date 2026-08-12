/**
 * ApprovalLineManagementPage — 결재선 MesEditableGrid 관리 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) mes-web SoPage와 동일 — PageCardSplit 상·하 + 패널별 그리드명·활성 이벤트
 *   2) 헤더는 행추가·저장·삭제, 상세는 선택 선의 단계만 인라인 편집한다
 *   3) 삭제는 validate-delete → 확인 → delete → 재조회와 객체 배열 업무키를 지킨다
 *
 * PIPELINE[HF87] 결재선 관리 화면
 * PIPELINE[HF86, HF29, HF39, HF90, HF52] 연관 모듈
 */
// 역할 — 상태·메모·목록 재조회
import { useCallback, useEffect, useMemo, useState } from "react";
// 역할 — 권한·비동기 중복 방지
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — mes-web형 그리드·CRUD 버튼
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — SoPage형 카드·검색·패널 헤더
import { PageCard, PageCardSplit } from "@/components/layout/PageCard";
import { PageHead, SearchArea, SearchButton } from "@/components/layout/SearchArea";
import { gridHeadClass, gridPanelClass, pageRootClass } from "@/components/layout/pageClasses";
// 역할 — 확인·토스트·오류·공통 문구
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { useSection } from "@/shell/useSection";
import { guardSaveWithKey } from "@/shell/gridRules";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 결재선 API
import {
  deleteApprovalLines,
  listApprovalLines,
  saveApprovalLine,
  validateDeleteApprovalLines,
  type ApprovalLine,
  type ApprovalStep,
} from "@/api/workflowApi";
// 역할 — 결재선코드 newOnly 규칙
import { APPROVAL_LINE_GRID_RULES } from "./ApprovalLineManagementPage.rules";

const ROLES: ApprovalStep["roleCd"][] = ["WRITE", "REVIEW", "APPROVE"];
const ROLE_LABEL: Record<ApprovalStep["roleCd"], string> = {
  WRITE: "작성",
  REVIEW: "검토",
  APPROVE: "승인",
};

type HeaderRow = ApprovalLine & { _key?: string };
type StepRow = ApprovalStep & { _key?: string; roleNm?: string };

function emptySteps(): ApprovalStep[] {
  return ROLES.map((roleCd, index) => ({ stepNo: index + 1, roleCd }));
}

function emptyLine(): ApprovalLine {
  return { apprLineCd: "", apprLineNm: "", useYn: "Y", steps: emptySteps() };
}

function normalizeSteps(steps: ApprovalStep[] | undefined): ApprovalStep[] {
  return ROLES.map((roleCd, index) => {
    const found = steps?.find((step) => step.roleCd === roleCd);
    return {
      stepNo: index + 1,
      roleCd,
      approverId: found?.approverId ?? null,
      deptCd: found?.deptCd ?? null,
      posCd: found?.posCd ?? null,
    };
  });
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 결재선 헤더·단계 그리드를 조회·추가·저장·삭제한다
 *   2) 일지설정 메뉴 approval-line-management에서 마운트한다
 *   3) 권한·검증 실패는 업무 토스트로만 안내한다
 */
export default function ApprovalLineManagementPage() {
  const screenCode = "approval-line-management";
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const asyncAct = useAsyncAction();
  // h=결재선, d=단계 — 활성 섹션(셸 단축키·패널 강조)
  const sec = useSection();
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [stepActiveKey, setStepActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };

  const hg = useEditableRows<HeaderRow>("apprLineCd");
  const sg = useEditableRows<StepRow>("roleCd");
  // 상단 결재선 — apprLineCd newOnly
  const grid = useGridAccess(APPROVAL_LINE_GRID_RULES, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  // 하단 단계 — 활성 그리드와 동일 access·onLockedAttempt
  const stepGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });

  const editable = canWrite || canModify;
  const headerColumns = useMemo<GridColumn<HeaderRow>[]>(() => [
    {
      // 결재선 업무키 — 신규 행에서만 입력
      field: "apprLineCd",
      header: "결재선코드",
      width: 120,
      required: true,
      editableOnNew: true,
    },
    {
      // 결재선 표시명
      field: "apprLineNm",
      header: "결재선명",
      width: 160,
      required: true,
      editable,
    },
    {
      // 사용여부
      field: "useYn",
      header: "사용",
      width: 80,
      type: "code",
      editable,
      codeOptions: [{ value: "Y", label: "사용" }, { value: "N", label: "미사용" }],
      codeMap: { Y: "사용", N: "미사용" },
    },
  ], [editable]);

  const stepColumns = useMemo<GridColumn<StepRow>[]>(() => [
    {
      // 고정 단계 번호 1~3
      field: "stepNo",
      header: "순서",
      width: 60,
      type: "number",
      editable: false,
    },
    {
      // 역할 코드 — WRITE/REVIEW/APPROVE 고정
      field: "roleCd",
      header: "역할코드",
      width: 90,
      editable: false,
      defaultHidden: true,
    },
    {
      // 역할 표시명
      field: "roleNm",
      header: "역할",
      width: 80,
      editable: false,
    },
    {
      // 결재자 사용자 ID
      field: "approverId",
      header: "결재자 ID",
      width: 120,
      editable,
    },
    {
      // 결재자 부서 코드
      field: "deptCd",
      header: "부서코드",
      width: 100,
      editable,
    },
    {
      // 결재자 직위 코드
      field: "posCd",
      header: "직위코드",
      width: 100,
      editable,
    },
  ], [editable]);

  const loadStepsFor = useCallback((line: HeaderRow | null) => {
    const steps = normalizeSteps(line?.steps);
    sg.load(steps.map((step) => ({ ...step, roleNm: ROLE_LABEL[step.roleCd] })));
    setStepActiveKey(null);
  // eslint-disable-next-line react-hooks/exhaustive-deps -- sg.load 안정 참조
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 결재선 헤더 목록을 다시 읽고 활성 행의 단계를 채운다
   *   2) 최초 진입·조회·저장·삭제 성공 뒤에 호출한다
   *   3) 실패하면 기존 행을 유지하고 오류 토스트만 표시한다
   */
  const load = useCallback(async () => {
    try {
      const rows = await listApprovalLines();
      hg.load(rows.map((row) => ({ ...row, steps: normalizeSteps(row.steps) })));
      setActiveKey(null);
      clearSel();
      loadStepsFor(null);
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- hg.load 안정 참조
  }, [loadStepsFor]);

  useEffect(() => { void load(); }, [load]);

  const activeHeader = useMemo(
    () => hg.rows.find((row) => row._key === activeKey) ?? null,
    [activeKey, hg.rows],
  );

  const handleAdd = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    sec.setSec("h");
    const key = hg.addRow(emptyLine());
    setActiveKey(key);
    loadStepsFor(emptyLine());
    clearSel();
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 활성 헤더 행과 단계 그리드를 합쳐 단건 저장한다
   *   2) GridCrudButtons·셸 Ctrl+S에서 호출한다
   *   3) 권한·필수값·확인 실패는 토스트만 표시한다
   */
  const handleSave = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const header = activeHeader ?? hg.rows.find((row) => row._rowState === "C" || row._rowState === "U") ?? null;
    if (!header) {
      // 헤더 dirty가 없어도 단계만 바뀐 경우 활성 행을 저장한다
      if (!activeKey) return mesToast(MES.selectRow, "warn");
    }
    const target = header ?? activeHeader;
    if (!target) return mesToast(MES.selectRow, "warn");

    const dirtyHeaders = hg.getSaveRows();
    const stepDirty = sg.getSaveRows().length > 0;
    if (dirtyHeaders.length === 0 && !stepDirty && target._rowState !== "C" && target._rowState !== "U") {
      return mesToast(MES.noChange, "warn");
    }

    const guard = guardSaveWithKey(grid.rules, grid.ctx, [target], headerColumns);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setActiveKey(guard.rowKey);
      return;
    }
    if (!String(target.apprLineCd ?? "").trim() || !String(target.apprLineNm ?? "").trim()) {
      return mesToast("결재선 코드와 결재선명을 입력하세요.", "warn");
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;

    const steps: ApprovalStep[] = sg.rows.map((row, index) => ({
      stepNo: index + 1,
      roleCd: row.roleCd,
      approverId: row.approverId || null,
      deptCd: row.deptCd || null,
      posCd: row.posCd || null,
    }));

    try {
      await saveApprovalLine({
        apprLineCd: String(target.apprLineCd).trim(),
        apprLineNm: String(target.apprLineNm).trim(),
        useYn: (target.useYn as "Y" | "N") ?? "Y",
        steps,
      });
      mesToast(MES.saveDone, "success");
      await load();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 선택·활성 헤더 행을 validate-delete·확인·delete한다
   *   2) GridCrudButtons·셸 삭제 단축키에서 호출한다
   *   3) 신규 행은 로컬 제거, 참조 차단은 업무 토스트로만 안내한다
   */
  const handleDelete = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(hg.rows, activeKey, setActiveKey, selKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");

    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = activeKey;
    for (const row of newRows) {
      const { focusKey } = hg.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setActiveKey(lastFocus);
      clearSel();
      loadStepsFor(hg.rows.find((row) => row._key === lastFocus) ?? null);
    }
    if (persisted.length === 0) return;

    const keys = persisted.map((row) => ({ apprLineCd: String(row.apprLineCd) }));
    try {
      await validateDeleteApprovalLines(keys);
      if (!(await mesConfirm(MES.deleteConfirm(String(persisted[0].apprLineNm ?? persisted[0].apprLineCd))))) return;
      await deleteApprovalLines(keys);
      clearSel();
      mesToast(MES.deleteDone, "success");
      await load();
    } catch (error) {
      mesError(error);
    }
  };

  const doSearch = () => asyncAct.run(async () => {
    sec.reset();
    await load();
  }, "search");

  // 셸 단축키 — 결재선은 헤더 기준(단계는 헤더와 함께 저장)
  usePageCommands({
    search: () => { void doSearch(); },
    add: handleAdd,
    save: () => { void asyncAct.run(handleSave, "save"); },
    del: () => { void asyncAct.run(handleDelete, "del"); },
  });

  const stepTitle = activeHeader
    ? `단계 (${activeHeader.apprLineNm || activeHeader.apprLineCd || "신규"})`
    : "단계";

  return (
    <div className={pageRootClass}>
      <PageHead
        // 화면 제목
        title="결재선 관리"
      />
      <PageCard
        // 조회만 검색 카드 — CRUD는 상단 패널 헤더
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={(
              <SearchButton
                // 조회 busy 스피너
                loading={asyncAct.isBusy("search")}
              />
            )}
          />
        )}
      >
        <PageCardSplit storageKey="haccp-split-approval-line">
          <div {...sec.bind("h", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>결재선</b>
              <GridCrudButtons
                // useAsyncAction.run — busy 키 래핑
                run={asyncAct.run}
                // 상단 결재선 전용 행추가
                onAdd={canWrite ? handleAdd : undefined}
                // 헤더+단계 단건 저장
                onSave={editable ? handleSave : undefined}
                // validate-delete 후 삭제
                onDel={canDelete ? handleDelete : undefined}
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
              />
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 결재선 헤더
              persistId="bas-approval-line-header"
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title="결재선"
              // 결재선 헤더 행 목록
              rows={hg.rows as EditableRow<HeaderRow>[]}
              // 코드·명칭·사용여부 고정 컬럼
              columns={headerColumns}
              // 등록·수정 권한이 있을 때만 편집
              editable={editable}
              // 패널 높이를 채운다
              height="100%"
              // 조회·저장·삭제 busy 오버레이
              loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
              // 활성 헤더 키
              activeKey={activeKey}
              // 헤더 선택 시 단계 그리드 동기화 + 섹션 h
              onActivate={(row) => {
                sec.setSec("h");
                sec.reset();
                setActiveKey(row._key);
                loadStepsFor(row);
              }}
              // 헤더 셀 변경 추적
              onCellChange={(key, field, value) => hg.updateCell(key, field as keyof HeaderRow, value)}
              // newOnly·읽기전용 접근 판정
              access={grid.access}
              // 잠금 셀 안내
              onLockedAttempt={grid.onLockedAttempt}
              // 셸·패널 활성 섹션을 헤더로
              onSetActive={() => sec.setSec("h")}
              // 다중 선택 삭제
              selectable
              onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
              selectionResetKey={selReset}
              showRowNum
            />
          </div>

          <div {...sec.bind("d", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>{stepTitle}</b>
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 결재 단계
              persistId="bas-approval-line-steps"
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title={stepTitle}
              // 선택 결재선의 고정 3단계
              rows={sg.rows as EditableRow<StepRow>[]}
              // 순서·역할·결재자·부서·직위 컬럼
              columns={stepColumns}
              // 헤더가 선택되고 권한이 있을 때만 편집
              editable={editable && !!activeKey}
              // 패널 높이를 채운다
              height="100%"
              loading={asyncAct.isBusy("search") || asyncAct.isBusy("save")}
              activeKey={stepActiveKey}
              // 단계 행 활성화 — 섹션 d
              onActivate={(row) => {
                sec.setSec("d");
                setStepActiveKey(row._key);
              }}
              // 단계 셀 변경 추적
              onCellChange={(key, field, value) => sg.updateCell(key, field as keyof StepRow, value)}
              // 하단도 활성 그리드와 동일 잠금·권한 이벤트
              access={stepGrid.access}
              onLockedAttempt={stepGrid.onLockedAttempt}
              // 셸·패널 활성 섹션을 단계로
              onSetActive={() => sec.setSec("d")}
              showRowNum
            />
          </div>
        </PageCardSplit>
      </PageCard>
    </div>
  );
}
