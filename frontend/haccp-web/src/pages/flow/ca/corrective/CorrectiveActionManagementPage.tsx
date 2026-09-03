/**
 * CorrectiveActionManagementPage — 이탈·개선조치 (그리드 1개).
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 작성 화면에서 이탈로 등록한 문서를 모두 모아 한 표에서 조치를 적는다
 *   2) 골격은 사용자 관리와 같다 — PageCardPanel · treePanelHeadClass · GridCrudButtons. 행추가는 없다
 *   3) 저장은 변경된 행만 건별로 보낸다. 완료 상태 삭제는 서버 SP 가 막는다
 *
 * 우측 상세 폼을 두지 않는다 — 적을 칸이 다섯이라 표에서 바로 치는 편이 빠르다.
 * 문서에서 온 칸(일자·양식·문서번호·작성자)은 잠근다. 원문서는 작성 화면에서 고친다.
 *
 * PIPELINE[HF89] 개선조치 관리 화면
 * PIPELINE[HF87, HF52, HF90] 연관 모듈
 */
// 역할 — React 상태·메모
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 개선조치 API
import {
  deleteCorrectiveActions,
  listCorrectiveActions,
  saveCorrectiveAction,
  validateDeleteCorrectiveActions,
} from "@/api/board/taskWorkflowApi";
// 역할 — 사용 중인 양식 목록 (검색 콤보)
import { listDocumentTemplates, type DocumentTemplateRow } from "@/api/documentApi";
// 역할 — mes-web형 그리드·헤더 CRUD 버튼
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — 페이지 카드·검색 영역
import { PageCard, PageCardPanel } from "@/components/layout/PageCard";
import {
  SearchArea,
  SearchButton,
  SearchDateRange,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { pageRootClass } from "@/components/layout/pageClasses";
import { treePanelHeadClass } from "@/components/layout/TreePanelSearch";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 권한·비동기·편집행·셸 명령
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useEditableRows } from "@/hooks/useEditableRows";
import { usePageCommands } from "@/shell/pageCommands";
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import type { EditableRow } from "@/types/editable";
// 역할 — 일자 YYYYMMDD ↔ input[type=date]
import { fromInputDate, toInputDate } from "@/lib/docDateTime";
// 역할 — 상태 콤보·표시명 정본 — CA_STATUS 공통코드
import { useCommonCodes } from "@/hooks/useCommonCodes";
import {
  PERSIST_ID,
  SCRN_CD,
  buildColumns,
  type Row,
} from "./CorrectiveActionManagementRule";

/**
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 이탈로 등록된 문서를 조회하고 조치 내용을 표에서 바로 적는다
 *   2) corrective-action-management 메뉴에서 마운트한다 — 본문 골격은 사용자 관리와 같다
 *   3) 권한·검증 실패는 업무 토스트로만 안내한다
 */
export default function CorrectiveActionManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canModify = useAuthStore((s) => s.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const asyncAct = useAsyncAction();
  const g = useEditableRows<Row>("idx");

  // 검색 조건 — 일자 구간·양식·작성자. 다른 작성 화면과 같은 순서다
  const [search, setSearch] = useState({ fromDt: "", toDt: "", tmplCd: "", writer: "" });
  const searchRef = useRef(search);
  searchRef.current = search;

  // 양식 콤보 — 회사가 쓰는 HWP·HTML 양식만
  const [forms, setForms] = useState<DocumentTemplateRow[]>([]);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const [loading, setLoading] = useState(false);

  // 상태 라벨은 화면이 만들지 않는다 — CA_STATUS 공통코드가 정본이다.
  // 오늘 할 일도 같은 코드를 읽는다. 한쪽만 하드코딩하면 같은 건이 두 이름으로 보인다
  const { codes: caStatusCodes, codeMap: caStatusNm } = useCommonCodes("CA_STATUS");
  // 대분류 자리표시 행(`*`)은 useCommonCodes 가 이미 뺀다 — 여기서 또 거르지 않는다
  const statusOptions = useMemo(
    () => caStatusCodes.map((row) => ({ value: row.subCd, label: row.codeNm })),
    [caStatusCodes],
  );
  const columns = useMemo(
    () => buildColumns(statusOptions, caStatusNm),
    [statusOptions, caStatusNm],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 이탈로 등록된 문서를 검색 조건으로 조회한다
   *   2) 조회 버튼·저장·삭제 후 호출한다
   *   3) 조건이 비면 서버가 전체로 본다
   */
  const load = useCallback(async () => {
    const q = searchRef.current;
    setLoading(true);
    try {
      const rows = await listCorrectiveActions({
        fromDt: q.fromDt,
        toDt: q.toDt,
        tmplCd: q.tmplCd,
        writer: q.writer.trim(),
      });
      g.load(rows as Row[]);
      setSelKeys([]);
      setSelReset((n) => n + 1);
    } catch (e) {
      mesError(e);
    } finally {
      setLoading(false);
    }
    // g 는 매 렌더 새 객체다 — 넣으면 조회가 무한히 돈다
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    void load();
    // 양식 콤보는 화면 진입 때 한 번만 읽는다
    void (async () => {
      try {
        setForms(await listDocumentTemplates());
      } catch (e) {
        mesError(e);
      }
    })();
  }, [load]);

  /** 저장 — 고친 행만 건별로 보낸다 */
  const handleSave = () =>
    asyncAct.run(async () => {
      const dirty = g.getSaveRows();
      if (dirty.length === 0) {
        mesToast(MES.noChange, "warn");
        return;
      }
      try {
        for (const row of dirty) {
          await saveCorrectiveAction({
            idx: row.idx,
            occurDt: row.occurDt,
            occurPlace: row.occurPlace,
            deviationDesc: row.deviationDesc,
            actionDesc: row.actionDesc,
            actionUserId: row.actionUserId,
            actionDt: row.actionDt,
            dueDt: row.dueDt,
            status: row.status,
          });
        }
        mesToast(MES.saveDone, "success");
        await load();
      } catch (e) {
        mesError(e);
      }
    }, "save");

  /** 삭제 — 체크된 행. 완료 건은 서버가 막는다 */
  const handleDelete = () =>
    asyncAct.run(async () => {
      const targets = g.rows.filter((row) => selKeys.includes(String(row.idx)));
      if (targets.length === 0) {
        mesToast(MES.selectRow, "warn");
        return;
      }
      const keys = targets.map((row) => ({ idx: Number(row.idx) }));
      try {
        await validateDeleteCorrectiveActions(keys);
        if (!(await mesConfirmDanger(MES.deleteConfirm(`${keys.length}건`)))) return;
        await deleteCorrectiveActions(keys);
        mesToast(MES.deleteDone, "success");
        await load();
      } catch (e) {
        mesError(e);
      }
    }, "del");

  usePageCommands({
    search: () => { void asyncAct.run(load, "search"); },
    save: canWrite || canModify ? () => { void handleSave(); } : undefined,
    del: canDelete ? () => { void handleDelete(); } : undefined,
  });

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            // 조회 — 검색조건으로 목록을 다시 읽는다
            onSearch={() => void asyncAct.run(load, "search")}
            actions={<SearchButton loading={loading || asyncAct.isBusy("search")} />}
          >
            <SearchDateRange
              // 일자 — 원문서 기준일 구간
              label="일자"
              from={toInputDate(search.fromDt)}
              to={toInputDate(search.toDt)}
              onFrom={(v: string) => setSearch((p) => ({ ...p, fromDt: fromInputDate(v) }))}
              onTo={(v: string) => setSearch((p) => ({ ...p, toDt: fromInputDate(v) }))}
            />
            <SearchSelect
              // 양식 — 회사가 쓰는 HWP·HTML 양식만 콤보에 올린다
              label="양식"
              value={search.tmplCd}
              onChange={(v) => setSearch((p) => ({ ...p, tmplCd: v }))}
            >
              <option value="">전체</option>
              {forms.map((form) => (
                <option key={form.tmplCd} value={form.tmplCd}>{form.tmplNm}</option>
              ))}
            </SearchSelect>
            <SearchField label="작성자">
              <input
                // 작성자 ID·이름 부분검색 — 서버 LIKE
                className={searchInputClass}
                value={search.writer}
                onChange={(e) => setSearch((p) => ({ ...p, writer: e.target.value }))}
              />
            </SearchField>
          </SearchArea>
        )}
      >
        <PageCardPanel className="p-2">
          <div className={treePanelHeadClass}>
            {/* 보이는 그리드명 — title prop 과 동일 */}
            <b>이탈·개선조치</b>
            <GridCrudButtons
              // 저장·삭제만. 행추가는 없다 — 이탈 행은 작성 화면에서 생긴다
              onSave={canWrite || canModify ? handleSave : undefined}
              onDel={canDelete ? handleDelete : undefined}
              // 버튼별 busy — handleSave/handleDelete 가 이미 asyncAct.run 을 쓴다
              busy={{
                save: asyncAct.isBusy("save"),
                del: asyncAct.isBusy("del"),
              }}
            />
          </div>
          <MesEditableGrid
            // 열 너비 저장 키 — 값 변경 금지
            persistId={PERSIST_ID}
            // pref 저장용 화면코드
            scrnCd={SCRN_CD}
            rows={g.rows as EditableRow<Row>[]}
            columns={columns}
            // 조치 칸만 편집 — 문서에서 온 칸은 컬럼 정의가 잠근다
            editable={canWrite || canModify}
            onCellChange={(key, field, value) => g.updateCell(key, field as keyof Row, value)}
            // 그리드 제목 — 패널 헤더와 동일
            title="이탈·개선조치"
            // 패널 높이를 채운다
            height="100%"
            // 조회·저장·삭제 busy 오버레이
            loading={loading || asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
            // 삭제 대상 체크박스
            selectable
            onSelectionChange={(picked) => setSelKeys(picked.map((row) => String(row.idx)))}
            selectionResetKey={selReset}
            showRowNum
          />
        </PageCardPanel>
      </PageCard>
    </div>
  );
}
