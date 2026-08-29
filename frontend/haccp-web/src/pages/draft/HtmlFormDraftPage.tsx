/**
 * HtmlFormDraftPage — 양식 작성 공통 화면 (상단 검색 · 좌 작성 목록 50% · 우 상세 50%).
 *
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) HYG(hyg-process)·CCP(ccp-verify)가 같은 프레임을 쓴다. 화면별로 다른 것은 config 뿐이다
 *      — 양식관리 5화면이 HtmlFormTemplatePage 를 공유하는 것과 같은 패턴이다
 *   2) 상단은 검색 전용(일자·양식코드·양식명·작성자ID·작성자명·결재 여부). 작성 입력과 섞지 않는다
 *   3) 오른쪽 상세는 왼쪽 기본정보(저장)를 한 뒤에만 수정할 수 있다 — docIdx 없으면 지면이 잠긴다
 *      우측 삭제도 전송대기만 켠다. 결재완료에서 버튼만 살아 있으면 지울 수 있어 보인다
 *
 * 전송·전송취소는 문서 허브 결재 API(processDocumentApproval REQUEST/CANCEL)를 그대로 쓴다.
 * 필수값은 저장 때 보지 않고 전송 직전에 htmlFormDraftShared.validateForTransfer 만 본다.
 *
 * PIPELINE[HF173] 양식 작성 공통 화면
 */
// 역할 — 상태·메모·초기 조회·화면별 지면 컴포넌트 타입
import { useCallback, useEffect, useMemo, useRef, useState, type ComponentType, type ReactNode } from "react";
// 역할 — URL 쿼리 add=1 소비
import { useSearchParams } from "react-router-dom";
// 역할 — 로그인 사용자·화면 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 지금 보고 있는 탭 — 숨은 탭이 남의 URL 쿼리를 먹지 않게 한다
import { useTabStore } from "@/stores/tabStore";
// 역할 — 비동기 중복 실행 차단·busy
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 좌측 draft·건별 버퍼·일괄 저장 세션
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";
// 역할 — URL ?docIdx= 자동 선택
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
// 역할 — 그리드 잠금·권한
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 셸 상단 툴바(조회·행추가·저장·삭제·인쇄·전송) 연결
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 확인·토스트
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
// 역할 — 오류 업무 문구
import { mesError } from "@/shell/errors";
// 역할 — 공통 안내 문구
import { MES } from "@/shell/messages";
// 역할 — 페이지 카드·검색 영역·좌우 분할
import { PageCard } from "@/components/layout/PageCard";
import {
  SearchArea,
  SearchButton,
  SearchDateRange,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
// 역할 — 편집 그리드·표준 버튼·입력
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 지면 공통 props·제목 메타를 뺀 점검 행
import { paperBodyItems, type HtmlFormPaperProps } from "@/components/form/htmlFormPaperShared";
// 역할 — 전송(REQUEST)·전송취소(CANCEL) 공통 결재 API
import { processDocumentApproval } from "@/api/documentApi";
// 역할 — 일자 YYYYMMDD ↔ input[type=date]
import { fromInputDate, toInputDate } from "@/lib/docDateTime";
// 역할 — 그리드·편집 행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 작성 화면 공통 API 계약
import type { HtmlFormDraftApi, HtmlFormDraftFile, HtmlFormDraftForm } from "@/api/draft/htmlFormDraftTypes";
// 역할 — 양식 선택 팝업 (일자·양식코드·양식명)
import { HtmlFormDeviationSignal } from "./HtmlFormDeviationSignal";
import { HtmlFormLookupModal } from "./HtmlFormLookupModal";
// 역할 — 공통 규칙(결재 여부 3단계·잠금·컬럼·필수값)
import {
  SEND_STATE_NM,
  buildDraftListColumns,
  canCancelSendDoc,
  canEditDetail,
  canModifyDoc,
  canSendDoc,
  detailToDraftBuf,
  draftPaperViewProps,
  emptyDraftBuf,
  htmlFormDraftGridRules,
  sendStateOf,
  validateForTransfer,
  firstInvalidTarget,
  type TransferBlock,
  type HtmlFormDraftBuf,
  type SendState,
} from "./htmlFormDraftShared";

/** 좌측 목록 행 메타 — 세션 공통 메타 + 작성 화면 표시 칸 */
type ListMeta = DocListMeta & {
  tmplCd: string;
  tmplNm: string;
  baseDtDisp?: string;
  writerNm?: string;
  sendState?: SendState;
  // 이탈여부 Y/N — 목록 칸을 쓰는 화면(HWP)만 채운다
  deviationYn?: string;
};

/** 우측 지면 편집 버퍼 — 문서 1건. 모양은 공통(htmlFormDraftShared)이 갖는다 */
type Buf = HtmlFormDraftBuf;



export interface HtmlFormDraftPageProps {
  // 화면코드 — tbl_screen.scrn_cd. 권한·그리드 pref·API 베이스 기준
  scrnCd: string;
  // 그리드 열 너비·정렬 저장 키. 값을 바꾸면 사용자 설정이 초기화된다
  persistId: string;
  // 좌우 분할 비율 저장 키
  splitKey: string;
  // 지면 제목 기본값 — 양식명이 없을 때만 쓴다
  paperTitle: string;
  // 지면 부제 — HYG (매일 작성) · CCP (매월 작성)
  paperSubtitle: string;
  // 좌측 패널 제목
  listTitle?: string;
  // 우측 지면 — 화면별 Paper 컴포넌트. renderDetail 을 넘기는 화면(HWP)은 두지 않는다
  PaperComponent?: ComponentType<HtmlFormPaperProps>;
  // 화면별 작성 API 묶음 — 경로·테이블은 여기가 정한다
  api: HtmlFormDraftApi;
  /**
   * 우측 상세를 Paper 대신 직접 그린다 — HWP 는 지면이 아니라 rhwp 편집기다.
   * 넘기지 않으면 PaperComponent 로 그린다 (HTML 작성 5화면).
   */
  renderDetail?: (ctx: HtmlFormDraftDetailCtx) => ReactNode;
  /**
   * 행 추가 직전에 여는 팝업 — HWP 만 넘긴다 (오늘 할일 문서주기).
   * 고른 값이 있으면 그 양식·일자로 행을 채우고, 취소(null)면 양식 선택 팝업을 연다.
   */
  pickBeforeAdd?: () => Promise<HtmlFormDraftPick | null>;
  /**
   * 저장이 끝난 뒤 화면이 더 할 일 — HWP 본문 파일 업로드가 여기 붙는다.
   * 던지면 저장 자체가 실패로 처리된다
   */
  afterSave?: (docIdx: number) => Promise<void>;
  /**
   * HWP 본문 dirty — 목록 _rowState 와 다른 축. HTML 5화면은 넘기지 않는다.
   * 목록이 깨끗한 채 칸만 고쳤을 때 덮어쓰기 저장을 타게 한다
   */
  isBodyDirty?: () => boolean;
  /**
   * 본문 dirty 해제 — 헤더 PUT 저장이 본문도 올렸을 때 호출한다
   */
  clearBodyDirty?: () => void;
  /**
   * 좌측 목록에 이탈여부 칸을 둔다 — HWP 작성만 켠다.
   * HTML 5화면은 지면 하단 시그널(HtmlFormDeviationSignal)이 같은 일을 하므로 두 곳에 두지 않는다.
   */
  showDeviationColumn?: boolean;
}

/** 행 추가 팝업이 고른 값 — 양식과 일자, 이미 만들어진 문서가 있으면 그 idx */
export interface HtmlFormDraftPick {
  tmplCd: string;
  tmplNm: string;
  // 기준일 YYYYMMDD — 비우면 오늘
  baseDt?: string;
  // 이미 있는 문서 — 새로 만들지 않고 그 문서를 연다
  docIdx?: number | null;
}

/** renderDetail 이 받는 값 — 우측을 직접 그리는 화면이 쓰는 최소 집합 */
export interface HtmlFormDraftDetailCtx {
  // 현재 열린 문서의 편집 버퍼. 고른 행이 없으면 null
  buf: Buf | null;
  // 저장된 문서 idx. 신규면 null
  docIdx: number | null;
  // 우측을 고칠 수 있는 상태인지 — 저장 전·전송 이후는 false
  canEdit: boolean;
  // 문서 첨부 목록 — HWP 본문을 여는 데 쓴다
  files: HtmlFormDraftFile[];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 상단 검색 + 좌 작성 목록 + 우 상세를 한 화면에서 본다
 *   2) HYG·CCP 작성 메뉴가 config 와 API 만 바꿔 연다
 *   3) 전송·전송취소는 저장된 문서만. 결재완료는 결재 쪽에서 취소한다
 */
export function HtmlFormDraftPage({
  scrnCd,
  persistId,
  splitKey,
  paperTitle,
  paperSubtitle,
  listTitle = "작성 목록",
  PaperComponent,
  api,
  renderDetail,
  pickBeforeAdd,
  afterSave,
  isBodyDirty,
  clearBodyDirty,
  showDeviationColumn = false,
}: HtmlFormDraftPageProps) {
  const user = useAuthStore((s) => s.user);
  // 지금 화면에 보이는 탭의 화면코드 — 숨은 탭은 URL 쿼리를 소비하지 않는다
  const activeTabCd = useTabStore((s) => s.activeCd);
  const canWrite = useAuthStore((s) => s.can(scrnCd, "write"));
  const canModify = useAuthStore((s) => s.can(scrnCd, "modify"));
  const canDelete = useAuthStore((s) => s.can(scrnCd, "delete"));
  const action = useAsyncAction();
  // 오늘 할 일 예정 행추가 쿼리 — add=1 을 한 번만 쓴다
  const [searchParams, setSearchParams] = useSearchParams();
  const [bootDone, setBootDone] = useState(false);
  const addQueryDone = useRef(false);

  // 작성 가능 양식 — 사용여부 예인 자사 양식만. 양식 선택 팝업 목록
  const [forms, setForms] = useState<HtmlFormDraftForm[]>([]);
  // 상단 검색 조건 6개 — 작성 입력과 별개다
  const [search, setSearch] = useState({
    fromDt: "", toDt: "", tmplCd: "", tmplNm: "", writerId: "", writerNm: "", sendState: "",
  });
  const searchRef = useRef(search);
  searchRef.current = search;

  // 양식 선택 팝업을 연 행 키 — null 이면 닫힘
  const [lookupKey, setLookupKey] = useState<string | null>(null);
  // 체크된 행 키 — 모두 전송·삭제 대상
  const [selKeys, setSelKeys] = useState<string[]>([]);
  // 체크 초기화 트리거 — 조회·삭제·전송 후 올린다
  const [selReset, setSelReset] = useState(0);
  // 좌측 목록 접힘 — 지면·편집기 폭을 넓히려고 접는다. 6개 작성 화면이 같게 동작한다
  const [listFolded, setListFolded] = useState(false);
  // 문서 첨부 목록 — HWP 만 쓴다. 우측을 직접 그리는 화면이 본문을 여는 데 필요하다
  const [detailFiles, setDetailFiles] = useState<HtmlFormDraftDetailCtx["files"]>([]);
  // 상세 요청 순번 — 늦게 온 응답이 나중 문서의 첨부를 덮는 것을 막는다
  const detailSeq = useRef(0);

  const {
    listRows, activeKey, activeBuffer: buf, addDraft, selectKey, patchActive,
    replaceServerList, removeDraft, saveAll, getBuffer, putBuffer,
  } = useDocFormSession<Buf, ListMeta>();

  // 저장 콜백 안에서 최신 활성 키·목록을 본다 — 콜백이 만들어진 시점 값이 아니라 실행 시점 값이 필요하다
  const activeKeyRef = useRef<string | null>(activeKey);
  const listRowsRef = useRef(listRows);
  activeKeyRef.current = activeKey;
  listRowsRef.current = listRows;

  const listGrid = useGridAccess(htmlFormDraftGridRules, {
    scrnCd,
    gridRole: "single",
    readOnly: !(canWrite || canModify),
  });

  const docIdx = buf?.docIdx ?? null;
  const status = buf?.status ?? null;
  // 오른쪽 상세는 저장된 전송대기 문서만 편집한다 — 저장 전 신규 행은 잠금
  const canEdit = canEditDetail(docIdx, status, canModify || canWrite);
  const canSend = canSendDoc(docIdx, status);
  const activeRow = listRows.find((r) => r._key === activeKey) ?? null;
  // 저장 안 한 변경이 남아 있을 때(= C·U) 전송 전에 저장을 먼저 묻는다
  const activeDirty = !!activeRow?._rowState;
  // 이탈·개선조치 근거 — 부적합 판정 행이 있거나 이탈내용·개선조치가 입력됐을 때
  const deviationForced = !!buf && (
    (buf.logRows ?? []).some((r) => r.judgeCd === "F")
    || !!buf.specialNote.trim()
    || !!buf.improveNote.trim()
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 서버 목록을 좌측에 싣는다. 결재 여부는 화면 3단계로 묶는다
   *   2) 조회·저장·삭제·전송 후 호출한다
   *   3) 결재 여부 검색은 DOC_STATUS 파생값이라 여기서 거른다. 신규 draft 는 유지된다
   */
  const loadList = useCallback(async () => {
    const q = searchRef.current;
    const rows = await api.list({
      tmplCd: q.tmplCd,
      tmplNm: q.tmplNm,
      fromDt: q.fromDt,
      toDt: q.toDt,
      writerId: q.writerId,
      writerNm: q.writerNm,
    });
    const mapped = rows
      .map((r) => ({
        docIdx: r.docIdx,
        docNo: r.docNo,
        tmplCd: r.tmplCd,
        tmplNm: r.tmplNm ?? "",
        status: r.status,
        baseKey: r.baseDt,
        baseDtDisp: toInputDate(r.baseDt),
        writerNm: r.writerNm ?? "",
        sendState: sendStateOf(r.status),
        ngCnt: r.ngCnt ?? 0,
        // 서버가 안 주는 화면(HTML)은 N — 칸 자체를 그리지 않는다
        deviationYn: (r.deviationYn ?? "N").toUpperCase() === "Y" ? "Y" : "N",
      }))
      .filter((r) => !q.sendState || r.sendState === q.sendState);
    replaceServerList(mapped, (r) => String(r.docIdx));
  }, [api, replaceServerList]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 진입 시 작성 가능 양식과 목록을 한 번 읽는다
   *   2) 양식이 없으면 양식관리 등록을 안내한다
   *   3) 최초 1회만 — 이후는 조회 버튼
   */
  useEffect(() => {
    void action.run(async () => {
      try {
        const rows = await api.listForms();
        setForms(rows);
        if (rows.length === 0) {
          mesToast("사용 중인 양식이 없습니다. 양식관리에서 사용여부를 예로 설정하세요.", "warn");
        }
        await loadList();
      } catch (e) {
        mesError(e);
      } finally {
        // 양식 목록을 읽은 뒤 오늘 할 일 add=1 쿼리를 받을 수 있다
        setBootDone(true);
      }
    }, "search");
    // 최초 1회
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 행을 열어 우측 상세에 싣는다. 버퍼가 있으면 서버를 다시 부르지 않는다
   *   2) 행 클릭·양식 선택·저장·전송 후 재적재에서 호출한다
   *   3) 양식 미선택 신규 행은 서버를 부르지 않고 빈 버퍼를 준다
   */
  const handleSelect = useCallback((key: string | null) => {
    /*
     * 첨부를 먼저 비운다.
     *
     * 문서를 바꾸면 docIdx 는 바로 바뀌는데 첨부는 상세 응답이 와야 바뀐다.
     * 그 틈에 우측 편집기가 「새 문서 + 앞 문서 첨부」를 보고 앞 문서 본문을 연다 —
     * 「빠르게 바꾸면 다른 파일이 열린다」가 이것이다. 실제로 843 자리에 844 본문이 실렸다.
     */
    setDetailFiles([]);
    // 늦게 온 상세가 다른 문서의 첨부를 덮지 않게 한다
    const seq = detailSeq.current + 1;
    detailSeq.current = seq;
    return selectKey(key, async (_k, row) => {
      // 아직 양식을 안 고른 행일 때(= 팝업 전) 상세를 부를 수 없다
      if (!row.tmplCd) return emptyDraftBuf(user);
      try {
        const detail = await api.detail(row.tmplCd, row.docIdx ?? null);
        // 첨부 목록 — 우측을 직접 그리는 화면(HWP)이 본문을 여는 데 쓴다.
        // 그 사이 사용자가 다른 문서로 갔으면 버린다
        if (detailSeq.current === seq) setDetailFiles(detail.files ?? []);
        return detailToDraftBuf(detail, { tmplCd: row.tmplCd, tmplNm: row.tmplNm }, user);
      } catch (error) {
        mesError(error);
        return null;
      }
    });
  }, [api, selectKey, user]);

  // 문서함 등에서 ?docIdx= 로 들어오면 그 문서를 연다
  const openDocIdx = useDocIdxQuery();
  const deepLinkRef = useRef<number | null>(null);
  useEffect(() => {
    if (openDocIdx == null || deepLinkRef.current === openDocIdx) return;
    if (!listRows.some((r) => r.docIdx === openDocIdx)) return;
    deepLinkRef.current = openDocIdx;
    void handleSelect(String(openDocIdx));
  }, [openDocIdx, listRows, handleSelect]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-26
   * 코멘트:
   *   1) 좌측 draft 행을 붙인다. 오늘 할 일 예정이면 그 행의 양식코드·일자를 그대로 넣는다
   *   2) 행추가 버튼·오늘 할 일 add=1 쿼리가 호출한다
   *   3) 양식이 있으면 팝업 없이 채운다. 없으면 양식 선택 팝업을 연다
   */
  const handleAdd = (
    // 오늘 할 일 예정 행의 양식·일자. 없으면(= 행추가 버튼) 팝업 경로
    forced?: HtmlFormDraftPick | null,
  ) => action.run(async () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (forms.length === 0) {
      mesToast("사용 중인 양식이 없습니다. 양식관리에서 사용여부를 예로 설정하세요.", "warn");
      return;
    }
    // 버튼일 때(= 강제 값이 없음) HWP 는 오늘 할일 팝업. 오늘 할 일 더블클릭은 forced 로 온다
    const picked = forced !== undefined ? forced : (pickBeforeAdd ? await pickBeforeAdd() : null);
    const next = emptyDraftBuf(user);
    if (picked?.baseDt && /^\d{8}$/.test(picked.baseDt)) next.baseKey = picked.baseDt;
    const key = addDraft({
      docIdx: null,
      docNo: "",
      tmplCd: "",
      tmplNm: "",
      status: null,
      baseKey: next.baseKey,
      baseDtDisp: toInputDate(next.baseKey),
      writerNm: user?.userNm ?? "",
      sendState: "wait",
      ngCnt: 0,
    }, next);
    // 할일에서 양식을 골랐으면 팝업을 다시 띄우지 않고 그 양식으로 채운다
    if (picked?.tmplCd) {
      await applyForm(key, picked.tmplCd, picked.tmplNm);
      return;
    }
    setLookupKey(key);
  }, "add");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-26
   * 코멘트:
   *   1) 오늘 할 일 예정 더블클릭이 붙인 add=1 쿼리를 한 번 소비한다
   *   2) 양식 목록 boot 가 끝난 뒤 행추가를 돌리고 add 만 지운다
   *   3) 새로고침 때 행이 또 생기지 않게 addQueryDone 으로 막는다
   */
  useEffect(() => {
    if (!bootDone || addQueryDone.current) return;
    /*
     * 이 화면이 지금 보고 있는 탭일 때만 쿼리를 먹는다.
     *
     * searchParams 는 라우터 전역인데 셸은 탭을 mount 한 채 숨긴다.
     * 그래서 열려 있는 작성 화면 **전부**가 add=1·tmplCd 를 자기 것으로 읽고
     * 남의 양식코드로 자기 API 를 불렀다 —
     * ccp-pkg 가 tml_ccp_mtl_002 로 detail 을 쳐서 400 이 났다.
     * 안 보이는 탭에 행이 하나씩 붙는 것도 같은 원인이다.
     */
    if (activeTabCd !== scrnCd) return;
    if (searchParams.get("add") !== "1") return;
    const tmplCd = (searchParams.get("tmplCd") ?? "").trim();
    addQueryDone.current = true;
    const next = new URLSearchParams(searchParams);
    next.delete("add");
    setSearchParams(next, { replace: true });
    if (!tmplCd) return;
    const tmplNm = (searchParams.get("tmplNm") ?? "").trim();
    const baseDt = (searchParams.get("baseDt") ?? "").trim();
    void handleAdd({
      tmplCd,
      tmplNm,
      baseDt: /^\d{8}$/.test(baseDt) ? baseDt : undefined,
    });
    // handleAdd 는 매 렌더 새 함수 — 쿼리는 ref 로 한 번만 쓴다
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTabCd, bootDone, scrnCd, searchParams, setSearchParams]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 팝업에서 고른 양식코드·양식명을 그 작성 행과 버퍼에 반영한다
   *   2) 양식 선택 팝업이 확정할 때 호출한다
   *   3) 고른 양식의 빈 점검표를 상세로 실어 오른쪽에 보여 준다(저장 전이라 편집은 잠김)
   */
  const applyForm = (key: string, tmplCd: string, tmplNm: string) => action.run(async () => {
    const prev = getBuffer(key);
    if (!prev) return;
    try {
      const detail = await api.detail(tmplCd, null);
      setDetailFiles(detail.files ?? []);
      const next = detailToDraftBuf(detail, { tmplCd, tmplNm }, user);
      // 이미 찍어 둔 일자는 유지한다 — 팝업은 양식만 바꾼다
      next.baseKey = prev.baseKey;
      next.docIdx = null;
      next.docNo = "";
      next.status = null;
      putBuffer(key, next, { tmplCd, tmplNm });
      if (activeKey !== key) await handleSelect(key);
    } catch (error) {
      mesError(error);
    }
  }, "form");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) dirty 전건을 검증·저장한다 — validate 만 좌/우 저장마다 다르다
   *   2) runSaveHeader·runSaveDetail 이 공통으로 호출한다
   *   3) 저장 후 목록을 다시 읽고 활성 행을 서버 키로 다시 연다. 임시 키를 getBuffer 하면 버퍼가 없다
   */
  const persistSave = useCallback(async (
    // dirty 행 검증 — 좌측 헤더·우측 작성 저장마다 규칙이 다르다
    validate: (
      dirty: EditableRow<ListMeta>[],
      getBuf: (key: string) => Buf | null,
    ) => { message: string; rowKey?: string } | null,
  ): Promise<boolean> => {
    const savedIdxs: number[] = [];
    // 저장 루프 시점의 활성 행 docIdx — remap 뒤 __new_* 버퍼는 없다
    let savedActiveIdx: number | null = null;
    const err = await saveAll({
      validate,
      saveOne: async (row, b) => {
        const saved = await api.save({
          tmplCd: b.tmplCd,
          docIdx: b.docIdx,
          baseDt: b.baseKey,
          checkerNm: b.checkerNm,
          approverNm: b.approverNm,
          verNo: b.verNo,
          items: paperBodyItems(b.items),
          specialNote: b.specialNote,
          improveNote: b.improveNote,
          actionNm: b.actionNm,
          confirmNm: b.confirmNm,
          // 기록 표 행 — 행 추가로 만든 행까지 그대로 DB 로 간다
          logRows: b.logRows,
          passRows: b.passRows,
          // 이탈여부 — 목록 칸을 쓰는 화면만. 서버가 개선조치 행을 만들거나 지운다
          deviationYn: showDeviationColumn
            ? ((row as EditableRow<ListMeta>).deviationYn ?? "N")
            : undefined,
        });
        /*
         * 저장 뒤 화면이 더 할 일 — HWP 는 여기서 본문 파일을 올린다.
         *
         * **지금 편집기에 열려 있는 행에만** 건다. 편집기는 한 문서만 들고 있어서
         * 모든 행에 걸면 그 하나의 본문이 저장된 문서 전부에 붙는다 —
         * 「왼쪽만 저장했는데 오른쪽이 엮인다」가 이것이고, 같은 본문을 연달아 올리다
         * 충돌(409)까지 났다. 열지 않은 행은 본문이 없는 게 맞다.
         */
        const isOpenRow = row._key === activeKeyRef.current;
        if (afterSave && isOpenRow) await afterSave(saved);
        savedIdxs.push(saved);
        if (isOpenRow) savedActiveIdx = saved;
        return {
          docIdx: saved,
          listMeta: {
            docIdx: saved,
            status: "WRK",
            sendState: "wait" as SendState,
            baseKey: b.baseKey,
            baseDtDisp: toInputDate(b.baseKey),
            deviationYn: (row as EditableRow<ListMeta>).deviationYn ?? "N",
          },
        };
      },
      afterAll: async () => {
        await loadList();
        for (const idx of savedIdxs) {
          try {
            const b = getBuffer(String(idx));
            const detail = await api.detail(b?.tmplCd ?? "", idx);
            setDetailFiles(detail.files ?? []);
            const next = detailToDraftBuf(detail, { tmplCd: b?.tmplCd ?? "", tmplNm: b?.tmplNm ?? "" }, user);
            putBuffer(String(idx), next, {
              status: next.status,
              sendState: sendStateOf(next.status),
              writerNm: next.writerNm,
            });
          } catch (e) {
            mesError(e);
          }
        }
        // 활성 행이 신규였을 때(= 임시 키) 서버 키로 다시 연다.
        // remap 뒤 getBuffer(__new_*) 는 null 이라 savedActiveIdx 로 집는다
        const focusIdx = savedActiveIdx ?? (savedIdxs.length === 1 ? savedIdxs[0] : null);
        if (focusIdx != null && savedIdxs.includes(focusIdx)) {
          await handleSelect(String(focusIdx));
        }
      },
    });
    if (err) {
      mesToast(err.message, "warn");
      return false;
    }
    // 헤더 PUT 저장이 본문 업로드까지 했으면 dirty 도 같이 내린다
    clearBodyDirty?.();
    return true;
  }, [afterSave, api, clearBodyDirty, getBuffer, handleSelect, loadList, putBuffer, saveAll, showDeviationColumn, user]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 좌측 기본정보(일자·양식코드)만 저장한다 — docIdx 를 만든다
   *   2) 좌측 저장 버튼이 호출한다
   *   3) 점검 행 개수는 보지 않는다 — BE 도 items 빈 배열을 허용한다
   */
  const runSaveHeader = useCallback(async (): Promise<boolean> => {
    return persistSave((dirty, getBuf) => {
      for (const row of dirty) {
        const key = row._key;
        if (!key) continue;
        const b = getBuf(key);
        if (!b) return { message: "편집 내용이 없습니다.", rowKey: key };
        // 전송 이후일 때(= 전송·결재완료) 저장 자체를 막는다. 서버도 다시 막는다
        if (!canModifyDoc(b.status) && b.docIdx) {
          return { message: "전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.", rowKey: key };
        }
        if (!b.tmplCd) return { message: "양식코드 버튼을 눌러 양식을 선택하세요.", rowKey: key };
        if (!/^\d{8}$/.test(b.baseKey)) return { message: MES.required("일자"), rowKey: key };
      }
      return null;
    });
  }, [persistSave]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 우측 작성값을 저장한다 — HTML 은 지면, HWP 는 본문 파일
   *   2) 우측 작성 후 저장·셸 저장·전송 전 저장이 호출한다
   *   3) 목록 dirty 면 헤더 PUT + afterSave. 본문만 dirty 면 파일 덮어쓰기만. 필수값은 전송 때 본다
   */
  const runSaveDetail = useCallback(async (): Promise<boolean> => {
    const listDirty = listRowsRef.current.some((r) => r._rowState === "C" || r._rowState === "U");
    // 목록이 깨끗할 때(= 일자·양식은 그대로) 본문만 고친 경우 — 메타 PUT 없이 파일만 덮어쓴다
    if (!listDirty) {
      /*
       * 본문 dirty 는 **추정**이다 — rhwp SDK 에 dirty API 가 없어 DOM 이벤트로 본다
       * (`installRhwpDirtyListeners`). 편집기 안에서 한 조작을 놓칠 수 있다.
       *
       * 그래서 문서형(HWP)은 「안 바뀐 것 같다」로 저장을 막지 않는다.
       * 문서를 열어 두고 저장을 누른 것은 「지금 내용으로 덮어써 달라」는 뜻이다 —
       * 추정 하나로 그걸 거절하면 사람이 쓴 것이 날아간다.
       * 지면형(HTML)은 dirty 가 React 상태라 믿을 수 있어 그대로 막는다.
       */
      const openBuf = activeKeyRef.current ? getBuffer(activeKeyRef.current) : null;
      const forceBody = !!renderDetail && !!openBuf?.docIdx;
      if (!forceBody && !isBodyDirty?.()) {
        mesToast("저장할 변경 내용이 없습니다.", "warn");
        return false;
      }
      const key = activeKeyRef.current;
      const b = key ? getBuffer(key) : null;
      if (!b?.docIdx) {
        mesToast("왼쪽에서 기본정보를 먼저 저장하세요.", "warn");
        return false;
      }
      // 전송 이후일 때(= 전송·결재완료) 본문 덮어쓰기도 막는다
      if (!canModifyDoc(b.status)) {
        mesToast("전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.", "warn");
        return false;
      }
      if (afterSave) await afterSave(b.docIdx);
      clearBodyDirty?.();
      return true;
    }
    return persistSave((dirty, getBuf) => {
      for (const row of dirty) {
        const key = row._key;
        if (!key) continue;
        const b = getBuf(key);
        if (!b) return { message: "편집 내용이 없습니다.", rowKey: key };
        if (!canModifyDoc(b.status) && b.docIdx) {
          return { message: "전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.", rowKey: key };
        }
        if (!b.tmplCd) return { message: "양식코드 버튼을 눌러 양식을 선택하세요.", rowKey: key };
        if (!/^\d{8}$/.test(b.baseKey)) return { message: MES.required("일자"), rowKey: key };
        // 지면 규칙은 지금 열려 있는 문서에만 건다 — 아직 저장 안 한 다른 행이 우측 저장·전송을 막지 않게 한다
        // (그 행들은 좌측 저장과 같은 기본정보 규칙만 통과하면 함께 커밋된다)
        if (key !== activeKey) continue;
        if (!b.docIdx) return { message: "왼쪽에서 기본정보를 먼저 저장하세요.", rowKey: key };
        // HWP 는 점검 행이 없다 — renderDetail 화면은 지면 행 검사를 생략한다
        if (!renderDetail && paperBodyItems(b.items).length === 0) {
          return { message: "점검 행이 없습니다.", rowKey: key };
        }
      }
      return null;
    });
  }, [activeKey, afterSave, clearBodyDirty, getBuffer, isBodyDirty, persistSave, renderDetail]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 좌측 일자·양식코드 등록만 저장한다 — 전송하지 않는다
   *   2) 좌측 저장 버튼이 호출한다
   *   3) 성공하면 오른쪽 작성 안내 토스트
   */
  const handleSaveHeader = () => action.run(async () => {
    try {
      if (await runSaveHeader()) {
        mesToast("기본정보를 저장했습니다. 오른쪽에서 작성하세요.", "success");
      }
    } catch (error) {
      mesError(error);
    }
  }, "saveHeader");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 우측 지면 작성값만 저장한다 — 전송하지 않고 전송대기를 유지한다
   *   2) 우측 작성 후 저장·셸 저장 명령이 호출한다
   *   3) 성공하면 저장 완료 토스트
   */
  const handleSaveDetail = () => action.run(async () => {
    try {
      if (await runSaveDetail()) mesToast(MES.saveDone, "success");
    } catch (error) {
      mesError(error);
    }
  }, "save");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 삭제 가능한 문서를 지우고 목록·상세를 정리한다 — 좌·우 삭제가 같은 업무 규칙을 쓴다
   *   2) 좌측 삭제(체크 행)·우측 삭제(현재 문서)가 호출한다
   *   3) 저장 전 draft 는 서버를 부르지 않고 행만 뺀다. 전송 이후는 대상에서 빼고 안내한다
   */
  const deleteRows = useCallback(async (keys: string[]): Promise<void> => {
    if (keys.length === 0) return mesToast(MES.selectRow, "warn");
    const rows = keys
      .map((key) => listRows.find((r) => r._key === key))
      .filter((r): r is EditableRow<ListMeta> => !!r);
    // 저장 전 행은 로컬에서만 뺀다
    const drafts = rows.filter((r) => r._rowState === "C");
    const saved = rows.filter((r) => r._rowState !== "C" && r.docIdx);
    // 전송·결재완료 행은 대상에서 빼고 사용자에게 알린다
    const locked = saved.filter((r) => r.sendState !== "wait");
    const target = saved.filter((r) => r.sendState === "wait");
    if (target.length === 0 && drafts.length === 0) {
      return mesToast("전송한 문서는 삭제할 수 없습니다. 전송취소 후 삭제하세요.", "warn");
    }
    if (target.length > 0 && !canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    try {
      if (target.length > 0) {
        // 양식코드별로 묶는다 — 금속검출은 서버가 양식코드로 문서를 찾는다.
        // 묶지 않고 부르면 양식코드가 비어 "양식 코드를 선택하세요." 로 막힌다
        const byTmpl = new Map<string, { docIdx: number }[]>();
        for (const row of target) {
          const tmplCd = row.tmplCd ?? "";
          const bucket = byTmpl.get(tmplCd) ?? [];
          bucket.push({ docIdx: Number(row.docIdx) });
          byTmpl.set(tmplCd, bucket);
        }
        for (const [tmplCd, docKeys] of byTmpl) {
          await api.validateDelete(docKeys, tmplCd);
        }
        const label = target.length === 1
          ? (target[0].docNo || target[0].tmplNm || "")
          : `${target.length}건을`;
        if (!await mesConfirmDanger(MES.deleteConfirm(label))) return;
        for (const [tmplCd, docKeys] of byTmpl) {
          await api.remove(docKeys, tmplCd);
        }
      }
      for (const row of drafts) {
        if (row._key) removeDraft(row._key);
      }
      if (target.length > 0) {
        mesToast(
          locked.length > 0
            ? `${target.length}건을 삭제했습니다. 전송한 ${locked.length}건은 제외했습니다.`
            : MES.deleteDone,
          "success",
        );
        await loadList();
        await handleSelect(null);
      }
      setSelKeys([]);
      setSelReset((n) => n + 1);
    } catch (error) {
      mesError(error);
    }
  }, [api, canDelete, handleSelect, listRows, loadList, removeDraft]);

  /** 좌측 삭제 — 체크된 행, 없으면 현재 행 */
  const handleDeleteLeft = () => action.run(
    async () => { await deleteRows(selKeys.length > 0 ? selKeys : activeKey ? [activeKey] : []); },
    "del",
  );

  /** 우측 삭제 — 현재 열려 있는 문서 1건 */
  const handleDeleteActive = () => action.run(
    async () => { await deleteRows(activeKey ? [activeKey] : []); },
    "del",
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 전송 후 목록과 버퍼를 서버 상태로 맞춘다
   *   2) 전송·전송취소 성공 직후 호출한다
   *   3) 활성 문서가 없으면 목록만 다시 읽는다
   */
  const reloadActive = useCallback(async () => {
    await loadList();
    if (!activeKey || !docIdx || !buf) return;
    try {
      const detail = await api.detail(buf.tmplCd, docIdx);
      const next = detailToDraftBuf(detail, { tmplCd: buf.tmplCd, tmplNm: buf.tmplNm }, user);
      putBuffer(activeKey, next, {
        status: next.status,
        sendState: sendStateOf(next.status),
      });
    } catch (error) {
      mesError(error);
    }
  }, [activeKey, api, buf, docIdx, loadList, putBuffer, user]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 미저장·변경분이 있으면 저장 후 전송할지 묻고, 아니오면 안내만 남긴다
   *   2) 우측 작성 후 저장과 모두 전송이 함께 쓴다 — 전송 전 작성값 저장 규칙을 한곳에 둔다
   *   3) 저장까지 끝났거나 처음부터 깨끗하면 true
   */
  const ensureSavedBeforeSend = useCallback(async (dirty: boolean): Promise<boolean> => {
    if (!dirty) return true;
    if (!await mesConfirm("저장되지 않은 변경사항이 있습니다. 저장 후 전송하시겠습니까?")) {
      mesToast("저장 후 전송해주세요.", "warn");
      return false;
    }
    return await runSaveDetail();
  }, [runSaveDetail]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 저장 상태를 확인하고 필수값을 검사한 뒤 결재선에 따라 전송(상신)한다
   *   2) 우측 전송 버튼·셸 전송 명령이 호출한다
   *   3) 저장 후 상태·필수값이 어긋나면 전송하지 않는다
   */
  /**
   * 개발자: 박승우
   * 일자: 2026-08-27
   * 코멘트:
   *   1) 전송을 막은 칸으로 지면을 스크롤하고 첫 입력칸에 포커스를 준다
   *   2) 전송 필수값 검사가 걸렸을 때만 호출한다
   *   3) 그 행을 못 찾으면 아무 일도 하지 않는다 — 토스트는 이미 떠 있다
   *
   * 항목형 지면은 data-item-cd, 기록 표는 data-log-seq, 통과표는 data-pass-seq 로 행을 찾는다.
   * 기록 표는 작업 전·후를 나눠 그려서 배열 위치로는 못 찾는다.
   */
  const focusBlockedCell = (block: TransferBlock) => {
    const sel = block.itemCd
      ? `[data-item-cd="${CSS.escape(block.itemCd)}"]`
      : block.logRowSeq != null ? `[data-log-seq="${block.logRowSeq}"]`
        : block.passRowSeq != null ? `[data-pass-seq="${block.passRowSeq}"]` : "";
    if (!sel) return;
    const row = document.querySelector<HTMLElement>(sel);
    if (!row) return;
    row.scrollIntoView({ block: "center", behavior: "smooth" });
    /*
     * 값 칸을 먼저 찾고, 없을 때만(= 라디오 전용 항목) 라디오에 포커스를 준다.
     * 한 selector 에 콤마로 묶으면 querySelector 가 문서 순서로 골라서
     * 값이 빈 항목인데도 앞에 있는 라디오가 잡힌다 — 커서가 엉뚱한 칸에 선다.
     */
    const value = row.querySelector<HTMLElement>(
      "input:not([type=radio]):not([type=checkbox]):not([disabled]):not([readonly]), textarea:not([disabled]):not([readonly])",
    );
    const target = value ?? row.querySelector<HTMLElement>("input[type=radio]:not([disabled])");
    target?.focus();
  };

  const handleSend = () => action.run(async () => {
    if (!activeKey || !buf) return mesToast(MES.selectRow, "warn");
    // docIdx 없을 때(= 좌측 기본정보 미저장) 전송 불가
    if (!buf.docIdx) return mesToast("왼쪽에서 기본정보를 먼저 저장하세요.", "warn");
    // 변경분이 남았을 때(= 목록 또는 본문 미저장) 작성 후 저장을 먼저 묻는다
    if (!await ensureSavedBeforeSend(activeDirty || !!isBodyDirty?.())) return;
    // 저장 뒤 세션 키가 docIdx 로 바뀌므로 버퍼를 다시 읽는다
    const cur = getBuffer(activeKey) ?? buf;
    const sendIdx = cur.docIdx;
    if (!canSendDoc(sendIdx, cur.status)) {
      return mesToast("전송대기 문서만 전송할 수 있습니다.", "warn");
    }
    /*
     * 필수값 기준은 공통 규칙 한곳 — 기준이 바뀌면 firstInvalidTarget 만 고친다.
     * renderDetail 을 넘긴 화면(= HWP 문서형)은 본문이 rhwp 파일이라 점검 항목이 없다.
     * 항목형 규칙을 그대로 태우면 「점검 행이 없습니다」로 영영 전송이 막힌다.
     */
    const block = firstInvalidTarget(cur.baseKey, cur.items, cur.logRows, !renderDetail, cur.passRows);
    if (block) {
      mesToast(block.message, "warn");
      // 문구만 띄우면 항목이 수십 개인 지면에서 어느 칸인지 사람이 찾아야 한다.
      // 현장에서 「빈칸 술래잡기」가 됐다는 보고가 있어 그 칸으로 옮겨 준다
      focusBlockedCell(block);
      return undefined;
    }
    if (!await mesConfirm("전송하시겠습니까?\n전송 후에는 수정·삭제할 수 없습니다.")) return;
    try {
      await processDocumentApproval({ docIdx: sendIdx as number, actionCd: "REQUEST" });
      mesToast("전송했습니다.", "success");
      await reloadActive();
    } catch (error) {
      mesError(error);
    }
  }, "send");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 체크한 행 중 전송 가능한 건만 모아 건수를 확인하고 일괄 전송한다
   *   2) 좌측 모두 전송 버튼이 호출한다
   *   3) 미체크·전송·결재완료·필수값 미충족 건은 대상에서 뺀다
   */
  const handleSendAll = () => action.run(async () => {
    if (selKeys.length === 0) return mesToast("전송할 행을 선택하세요.", "warn");
    // 전송대기 행만 후보다 — 전송·결재완료는 여기서 제외된다
    const picked = selKeys
      .map((key) => listRows.find((r) => r._key === key))
      .filter((r): r is EditableRow<ListMeta> => !!r && r.sendState === "wait");
    if (picked.length === 0) return mesToast("전송 가능한 건이 없습니다.", "warn");
    // docIdx 없는 행은 좌측 기본정보 저장이 선행되어야 한다
    if (picked.some((r) => !r.docIdx)) {
      return mesToast("왼쪽에서 기본정보를 먼저 저장하세요.", "warn");
    }
    // 후보 중 변경분이 있으면 작성 후 저장부터 한다 — 본문 dirty 도 같은 축으로 본다
    const dirty = picked.some((r) => !!r._rowState) || !!isBodyDirty?.();
    if (!await ensureSavedBeforeSend(dirty)) return;

    try {
      // 저장 뒤 draft 키가 docIdx 키로 바뀌므로 버퍼에서 다시 찾는다
      const targets: number[] = [];
      let skipped = 0;
      for (const row of picked) {
        const key = row.docIdx ? String(row.docIdx) : row._key;
        const b = key ? getBuffer(key) : null;
        const idx = b?.docIdx ?? row.docIdx ?? null;
        if (!idx || !canSendDoc(idx, b?.status ?? row.status)) {
          skipped += 1;
          continue;
        }
        // 버퍼가 없는 행(= 아직 열어 보지 않음)은 필수값 검사를 위해 상세를 읽는다
        const cur = b ?? detailToDraftBuf(
          await api.detail(row.tmplCd, idx),
          { tmplCd: row.tmplCd, tmplNm: row.tmplNm },
          user,
        );
        // 필수값이 빈 건은 전송 가능 건이 아니다
        if (validateForTransfer(cur.baseKey, cur.items, cur.logRows, !renderDetail, cur.passRows)) {
          skipped += 1;
          continue;
        }
        targets.push(idx);
      }
      if (targets.length === 0) return mesToast("전송 가능한 건이 없습니다.", "warn");
      if (!await mesConfirm(`전송 가능한 건은 총 ${targets.length}건입니다. 전송하시겠습니까?`)) return;

      for (const idx of targets) {
        await processDocumentApproval({ docIdx: idx, actionCd: "REQUEST" });
      }
      mesToast(
        skipped > 0
          ? `${targets.length}건을 전송했습니다. 전송 불가 ${skipped}건은 제외했습니다.`
          : `${targets.length}건을 전송했습니다.`,
        "success",
      );
      setSelKeys([]);
      setSelReset((n) => n + 1);
      await reloadActive();
    } catch (error) {
      mesError(error);
    }
  }, "sendAll");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-24
   * 코멘트:
   *   1) 전송을 취소해 전송대기로 되돌린다
   *   2) 전송취소 버튼이 호출한다
   *   3) 검토·승인이 시작된 문서는 서버가 거부한다. 결재완료는 결재 쪽에서 취소한다
   */
  const handleCancelSend = () => action.run(async () => {
    if (!docIdx) return mesToast(MES.selectRow, "warn");
    if (!canCancelSendDoc(docIdx, status)) {
      return mesToast("전송 상태에서만 전송취소할 수 있습니다.", "warn");
    }
    if (!await mesConfirm("전송을 취소하고 전송대기로 되돌리시겠습니까?")) return;
    try {
      await processDocumentApproval({ docIdx, actionCd: "CANCEL" });
      mesToast("전송을 취소했습니다. 다시 수정할 수 있습니다.", "success");
      await reloadActive();
    } catch (error) {
      mesError(error);
    }
  }, "cancel");

  const handleSearch = useCallback(() => {
    void action.run(async () => {
      try {
        await loadList();
        setSelKeys([]);
        setSelReset((n) => n + 1);
      } catch (e) {
        mesError(e);
      }
    }, "search");
  }, [action, loadList]);

  const listCols = useMemo(
    () => buildDraftListColumns((row) => {
      // 양식코드 버튼 — 그 행의 양식 선택 팝업을 연다
      const key = (row as EditableRow<ListMeta>)._key;
      if (key) setLookupKey(key);
    }, showDeviationColumn) as GridColumn<ListMeta>[],
    [showDeviationColumn],
  );

  // 팝업이 열린 행 — 현재 양식코드를 강조하려고 같이 찾는다
  const lookupRow = lookupKey ? listRows.find((r) => r._key === lookupKey) ?? null : null;

  usePageCommands({
    search: handleSearch,
    add: () => { void handleAdd(); },
    save: () => { void handleSaveDetail(); },
    del: () => { void handleDeleteLeft(); },
    print: () => { window.print(); },
    transfer: () => { void handleSend(); },
  });

  // 우측 상세 한 덩어리 — 좌측을 접었을 때도 같은 것을 그린다.
  // 두 곳에 복제하면 접기 여부에 따라 화면이 갈린다
  const detailPane = (
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2 overflow-hidden">
                  <MesButton
                    // 좌측 목록 접기·펴기 — 지면·편집기 폭을 넓힐 때 쓴다. 6개 작성 화면이 같게 동작한다
                    size="sm"
                    variant="ghost"
                    // 부모가 overflow-hidden 이라 줄지 않으면 넉 자가 두 줄로 접혀 세로로 깨져 보였다
                    className="shrink-0 whitespace-nowrap"
                    title={listFolded ? "작성 목록 펴기" : "작성 목록 접기"}
                    onClick={() => setListFolded((prev) => !prev)}
                  >
                    {listFolded ? "목록 펴기" : "목록 접기"}
                  </MesButton>
                  <b
                    // 폭이 모자라면 말줄임한다 — 잘린 이름을 마우스로 확인할 수 있게 전체를 title 에 둔다
                    className="truncate"
                    title={buf?.tmplNm || paperTitle}
                  >
                    {buf?.tmplNm || paperTitle}
                  </b>
                  {buf ? (
                    <span className="text-xs font-normal text-slate-500">
                      {SEND_STATE_NM[sendStateOf(status)]}
                      {buf.docNo ? ` · ${buf.docNo}` : ""}
                      {!canEdit && buf.docIdx ? " · 수정 불가" : ""}
                    </span>
                  ) : null}
                  {buf && !buf.docIdx ? (
                    /*
                     * 저장 전에는 지면 칸이 전부 잠긴다 — docIdx 가 있어야 지면을 만들 수 있다.
                     * 회색 작은 글씨로 붙여 뒀더니 실무 검증에서 세 사람이 연달아
                     * 「칸이 안 써진다」로 막혔다. 눈에 띄게 띄우고 무엇을 눌러야 하는지 적는다.
                     */
                    <span className="rounded bg-amber-50 px-2 py-0.5 text-xs font-normal text-amber-800">
                      왼쪽 목록에서 <b>저장</b>을 먼저 눌러야 이 지면에 값을 쓸 수 있습니다
                    </span>
                  ) : null}
                </div>
                <div className="ml-auto flex shrink-0 items-center gap-1.5">
                  <MesButton
                    // 작성 후 저장 — 지면 점검값·하단칸만 저장한다. 전송하지 않는다
                    size="sm"
                    variant="save"
                    icon="save"
                    disabled={!buf || !canEdit || action.isBusy()}
                    loading={action.isBusy("save")}
                    onClick={() => void handleSaveDetail()}
                  >
                    작성 후 저장
                  </MesButton>
                  <MesButton
                    // 전송 — 미저장 확인 → 필수값 검사 → 결재선 상신(REQUEST)
                    size="sm"
                    variant="excel"
                    icon="approve"
                    disabled={!buf || !canSend || action.isBusy()}
                    loading={action.isBusy("send")}
                    onClick={() => void handleSend()}
                  >
                    전송
                  </MesButton>
                  <MesButton
                    // 삭제 — 저장된 전송대기만. 전송·결재완료는 핸들러가 막아도 버튼부터 끈다
                    size="sm"
                    variant="danger"
                    icon="trash"
                    disabled={!buf || !buf.docIdx || !canModifyDoc(status) || action.isBusy()}
                    loading={action.isBusy("del")}
                    onClick={() => void handleDeleteActive()}
                  >
                    삭제
                  </MesButton>
                  <MesButton
                    // 전송취소 — 상신취소(CANCEL). 전송대기로 되돌린다
                    size="sm"
                    variant="secondary"
                    icon="reset"
                    disabled={!canCancelSendDoc(docIdx, status) || action.isBusy()}
                    loading={action.isBusy("cancel")}
                    onClick={() => void handleCancelSend()}
                  >
                    전송취소
                  </MesButton>
                </div>
              </div>
              <div className="min-h-0 flex-1 overflow-auto">
                {renderDetail ? (
                  renderDetail({ buf, docIdx, canEdit, files: detailFiles })
                ) : buf && buf.tmplCd && PaperComponent ? (
                  <>
                  <PaperComponent
                    // 작성 모드 — 기준관리(template)가 아니다
                    mode="write"
                    // 패널 채움 — 인쇄는 브라우저 인쇄에 맡긴다
                    variant="fill"
                    // 저장 전이거나 전송 이후면 잠금
                    locked={!canEdit}
                    editable={canEdit}
                    // 헤더·점검 행·하단 4열·기록 표 — 결재 미리보기와 같은 값을 쓴다
                    {...draftPaperViewProps(buf, { paperTitle, paperSubtitle })}
                    onHeaderChange={(patch) => patchActive((cur) => {
                      const next = { ...cur };
                      if (patch.baseDt != null) next.baseKey = fromInputDate(patch.baseDt);
                      // 이름이 바뀌었을 때(= 다른 사람) 서명 스냅샷을 지운다. 저장 때 다시 붙는다
                      if (patch.checkerNm != null) {
                        if (patch.checkerNm !== cur.checkerNm) {
                          next.checkerId = "";
                          next.checkerSignYn = "N";
                        }
                        next.checkerNm = patch.checkerNm;
                      }
                      if (patch.approverNm != null) {
                        if (patch.approverNm !== cur.approverNm) {
                          next.approverId = "";
                          next.approverSignYn = "N";
                        }
                        next.approverNm = patch.approverNm;
                      }
                      return next;
                    }, patch.baseDt != null ? { baseDtDisp: patch.baseDt } : undefined)}
                    onItemsChange={(items) => patchActive((cur) => ({ ...cur, items }))}
                    // 기록 표 행 값은 위 spread 가 넘긴다. 여기는 편집 콜백만 붙인다
                    onLogRowsChange={(logRows) => patchActive((cur) => ({ ...cur, logRows }))}
                    onPassRowsChange={(passRows) => patchActive((cur) => ({ ...cur, passRows }))}
                    onFooterChange={(patch) => patchActive((cur) => {
                      const next = { ...cur, ...patch };
                      if (patch.confirmNm != null && patch.confirmNm !== cur.confirmNm) {
                        next.confirmId = "";
                        next.confirmSignYn = "N";
                      }
                      return next;
                    })}
                  />
                    <HtmlFormDeviationSignal
                      // 부적합 행이나 이탈·개선 입력이 있을 때(= 근거 있음) 자동으로 켜고 잠근다
                      forced={deviationForced}
                      checked={buf.deviationYn}
                      editable={canEdit}
                      onChange={(next) => patchActive((cur) => ({ ...cur, deviationYn: next }))}
                    />
                  </>
                ) : (
                  <p className="p-6 text-sm text-slate-500">
                    {buf
                      ? "양식코드 버튼을 눌러 작성할 양식을 선택하세요."
                      : "왼쪽에서 문서를 고르거나 「행추가」를 눌러 작성하세요."}
                  </p>
                )}
              </div>
            </div>
  );

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            // 조회 — 검색조건으로 좌측 목록을 다시 읽는다. 이 영역은 검색 전용이다
            onSearch={handleSearch}
            actions={<SearchButton loading={action.isBusy("search")} />}
          >
            <SearchDateRange
              // 일자 — YYYYMMDD 상태를 input[type=date] 로 변환한 구간 검색
              label="일자"
              from={toInputDate(search.fromDt)}
              to={toInputDate(search.toDt)}
              onFrom={(v) => setSearch((prev) => ({ ...prev, fromDt: fromInputDate(v) }))}
              onTo={(v) => setSearch((prev) => ({ ...prev, toDt: fromInputDate(v) }))}
            />
            <SearchField label="양식코드">
              <input
                // 양식코드 부분검색 — 직접 입력한다. 팝업이 아니다(팝업은 하단 작성 행 전용)
                className={searchInputClass}
                value={search.tmplCd}
                placeholder="양식코드"
                onChange={(event) => setSearch((prev) => ({ ...prev, tmplCd: event.target.value }))}
              />
            </SearchField>
            <SearchField label="양식명">
              <input
                // 양식명 부분검색 — 서버 LIKE
                className={searchInputClass}
                value={search.tmplNm}
                placeholder="양식명"
                onChange={(event) => setSearch((prev) => ({ ...prev, tmplNm: event.target.value }))}
              />
            </SearchField>
            <SearchField label="작성자 ID">
              <input
                // 작성자 ID 부분검색 — tbl_document.writer_id
                className={searchInputClass}
                value={search.writerId}
                placeholder="작성자 ID"
                onChange={(event) => setSearch((prev) => ({ ...prev, writerId: event.target.value }))}
              />
            </SearchField>
            <SearchField label="작성자명">
              <input
                // 작성자명 부분검색 — tbl_user.user_nm
                className={searchInputClass}
                value={search.writerNm}
                placeholder="작성자명"
                onChange={(event) => setSearch((prev) => ({ ...prev, writerNm: event.target.value }))}
              />
            </SearchField>
            <SearchSelect
              // 결재 여부 — DOC_STATUS 파생 3단계라 화면에서 거른다
              label="결재 여부"
              value={search.sendState}
              onChange={(v) => setSearch((prev) => ({ ...prev, sendState: v }))}
            >
              <option value="">전체</option>
              {(Object.keys(SEND_STATE_NM) as SendState[]).map((key) => (
                <option key={key} value={key}>{SEND_STATE_NM[key]}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        )}
      >
        {listFolded ? (
          <div className="mes-page-split flex min-h-0 h-full flex-1 flex-col gap-0">
            <div className={splitPanelClass}>{detailPane}</div>
          </div>
        ) : (
        <ResizableSplit
          // 좌 작성 목록 50 · 우 상세 50 — 양식관리와 같은 프레임
          orientation="horizontal"
          storageKey={splitKey}
          defaultPrimaryPct={50}
          minPct={25}
          maxPct={75}
          className="mes-page-split min-h-0 h-full flex-1 gap-0"
          primary={(
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2">
                  <b>{listTitle}</b>
                  {selKeys.length > 0 ? (
                    <span className="text-xs font-normal text-slate-500">{`${selKeys.length}건 선택`}</span>
                  ) : null}
                </div>
                <div className="ml-auto flex shrink-0 items-center gap-1.5">
                  <MesButton
                    // 행 추가 — 오늘 날짜·양식 미선택으로 열고 양식 선택 팝업을 띄운다
                    size="sm"
                    variant="add"
                    icon="plus"
                    disabled={action.isBusy()}
                    loading={action.isBusy("add")}
                    onClick={() => void handleAdd()}
                  >
                    행추가
                  </MesButton>
                  <MesButton
                    // 저장 — 일자·양식코드 등록. docIdx 생성 후 오른쪽 작성이 열린다
                    size="sm"
                    variant="save"
                    icon="save"
                    disabled={action.isBusy()}
                    loading={action.isBusy("saveHeader")}
                    onClick={() => void handleSaveHeader()}
                  >
                    저장
                  </MesButton>
                  <MesButton
                    // 삭제 — 체크된 행, 없으면 현재 행. 우측 삭제와 같은 업무 규칙
                    size="sm"
                    variant="danger"
                    icon="trash"
                    disabled={action.isBusy()}
                    loading={action.isBusy("del")}
                    onClick={() => void handleDeleteLeft()}
                  >
                    삭제
                  </MesButton>
                  <MesButton
                    // 모두 전송 — 체크된 행 중 전송 가능한 건만 대상으로 한다
                    size="sm"
                    variant="excel"
                    icon="approve"
                    disabled={selKeys.length === 0 || action.isBusy()}
                    loading={action.isBusy("sendAll")}
                    onClick={() => void handleSendAll()}
                  >
                    모두 전송
                  </MesButton>
                </div>
              </div>
              <MesEditableGrid
                // 열 너비·정렬 저장 키
                persistId={persistId}
                // 권한·pref 범위
                scrnCd={scrnCd}
                // 서버 목록 + 신규 draft
                rows={listRows as EditableRow<ListMeta>[]}
                // 결재 여부·일자·양식코드(팝업 버튼)·양식명·작성자
                columns={listCols}
                // 신규·전송대기 행 일자 편집. 전송 이후 행은 규칙이 잠근다
                editable={canWrite || canModify}
                // 패널 제목 — 헤더 b 와 같은 문구
                title={listTitle}
                // 부모 flex 높이
                height="100%"
                loading={action.isBusy("search")}
                // 맨 앞 체크박스 — 모두 전송·삭제 대상 선택
                selectable
                // 체크 변경 시 선택 키 보관
                onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key).filter(Boolean) as string[])}
                // 조회·삭제·전송 후 체크 해제
                selectionResetKey={selReset}
                // 선택 키
                activeKey={activeKey}
                // 행 클릭 시 우측 상세 전환
                onActivate={(row) => { void handleSelect(row._key ?? null); }}
                onCellChange={(key, field, cellValue) => {
                  /*
                   * 이탈여부 — HWP 화면만 목록 칸으로 켠다.
                   * HTML 5화면은 지면 하단 시그널이 같은 일을 하고 이 칸 자체가 없다.
                   * 목록 메타(listPatch)와 버퍼를 같이 올려야 저장 payload 에 실린다 —
                   * 한쪽만 고치면 체크는 보이는데 저장이 안 된다.
                   */
                  if (field === "deviationYn") {
                    const on = cellValue === true || String(cellValue ?? "").toUpperCase() === "Y";
                    const yn = on ? "Y" : "N";
                    const cur = getBuffer(key);
                    if (!cur) return;
                    if (key === activeKey) {
                      patchActive((prev) => ({ ...prev, deviationYn: on }), {
                        deviationYn: yn,
                      } as Partial<ListMeta>);
                      return;
                    }
                    putBuffer(key, { ...cur, deviationYn: on }, { deviationYn: yn } as Partial<ListMeta>);
                    return;
                  }
                  // 일자 — 전송대기 행에서 셀 편집. 양식코드는 팝업, 나머지는 잠금 규칙이 막는다
                  if (field !== "baseDtDisp") return;
                  const next = fromInputDate(String(cellValue ?? ""));
                  const prevBuf = getBuffer(key);
                  if (!prevBuf) return;
                  const listPatch = { baseKey: next, baseDtDisp: toInputDate(next) };
                  // 편집한 행이 활성 행일 때(= 셀 편집은 행을 먼저 활성화해야 가능) 행을 dirty 로 올린다.
                  // putBuffer 는 _rowState 를 건드리지 않아 저장행 일자 수정이 좌측 저장에서 누락된다
                  if (key === activeKey) {
                    patchActive((cur) => ({ ...cur, baseKey: next }), listPatch);
                    return;
                  }
                  // 활성 행이 아닌 셀은 편집될 수 없다 — 방어용 경로
                  putBuffer(key, { ...prevBuf, baseKey: next }, listPatch);
                }}
                // 잠금·권한 판정
                access={listGrid.access}
                onLockedAttempt={listGrid.onLockedAttempt}
                showRowNum
              />
            </div>
          )}
          secondary={detailPane}
        />
        )}
      </PageCard>

      {lookupKey ? (
        <HtmlFormLookupModal
          // 열 설정 pref 화면코드
          scrnCd={scrnCd}
          // 사용여부 예인 자사 양식만 — 진입 시 읽어 둔 목록
          forms={forms}
          // 현재 행의 양식 강조
          value={lookupRow?.tmplCd || undefined}
          // 선택 확정 — 양식코드·양식명을 작성 행에 반영
          onSelect={(tmplCd, tmplNm) => { void applyForm(lookupKey, tmplCd, tmplNm); }}
          // 선택 없이 닫기
          onClose={() => setLookupKey(null)}
        />
      ) : null}
    </div>
  );
}
