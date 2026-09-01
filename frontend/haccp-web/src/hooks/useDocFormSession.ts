/**
 * useDocFormSession — DB형 문서 화면의 좌측 draft·다건 버퍼·일괄 저장 세션.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 신규 시 좌측 그리드에 C행을 쌓고 건별 본문 버퍼를 둔다
 *   2) 저장은 dirty 전건 검증 후 단건 save를 순차 호출한다
 *   3) CCP·위생·BizOps DocFormLayout 화면이 동일 계약을 쓴다
 *
 * PIPELINE[HF120] DB형 문서 세션
 * PIPELINE[HF81, HF83, HF85] 연관 모듈
 */
// 역할 — React 상태·ref·콜백
import { useCallback, useRef, useState } from "react";
// 역할 — 편집 행 타입
import type { EditableRow } from "@/types/editable";
// 역할 — 셸 beforeunload dirty 등록
import { useRegisterPageDirty } from "@/shell/pageDirtyRegistry";

/** 신규 draft _key — Date.now + 시퀀스 */
let _seq = 0;
const uid = () => `__new_${Date.now()}_${_seq++}`;

/** 좌측 목록 공통 메타 — 양식별 필드는 확장 */
export type DocListMeta = {
  // 저장 문서 PK — draft는 없음
  docIdx?: number | null;
  // 문서번호 표시
  docNo?: string;
  // DOC_STATUS
  status?: string | null;
  // 기준키 원문 (YYYYMMDD / YYYY / YYYYMM)
  baseKey: string;
  // 부적합 건수 (없으면 0)
  ngCnt?: number;
};

export type DocFormSessionValidateResult = {
  // 업무 안내 문구
  message: string;
  // 포커스할 draft _key
  rowKey?: string;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 목록·버퍼·activeKey를 한 세션으로 관리한다
 *   2) DocForm 계열 페이지에서 호출한다
 *   3) 검증 실패는 saveAll이 결과 객체로 반환한다
 */
export function useDocFormSession<TBuf, TList extends DocListMeta>() {
  const [listRows, setListRows] = useState<EditableRow<TList>[]>([]);
  const listRef = useRef<EditableRow<TList>[]>([]);
  const buffersRef = useRef<Map<string, TBuf>>(new Map());
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [activeBuffer, setActiveBuffer] = useState<TBuf | null>(null);
  // 버퍼 버전 — 선택 전환 시 리렌더
  const [, setBump] = useState(0);
  const bump = useCallback(() => setBump((n) => n + 1), []);

  const syncList = useCallback((next: EditableRow<TList>[]) => {
    listRef.current = next;
    setListRows(next);
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 서버 목록으로 비-draft 행을 교체하고 C draft는 유지한다
   *   2) 조회·저장 후 호출한다
   *   3) dirty(U) 키는 버퍼가 남아 있으면 U 표시를 유지한다
   */
  const replaceServerList = useCallback((server: TList[], keyOf: (row: TList) => string) => {
    const drafts = listRef.current.filter((r) => r._rowState === "C");
    const dirtyU = new Set(
      listRef.current.filter((r) => r._rowState === "U").map((r) => r._key).filter(Boolean) as string[],
    );
    const mapped = server.map((row) => {
      const key = keyOf(row);
      return {
        ...row,
        _key: key,
        _rowState: dirtyU.has(key) && buffersRef.current.has(key) ? ("U" as const) : undefined,
      } as EditableRow<TList>;
    });
    // 서버에 없는 dirty U 키의 버퍼는 정리 (삭제된 문서)
    const serverKeys = new Set(mapped.map((r) => r._key));
    for (const key of [...buffersRef.current.keys()]) {
      const isDraft = drafts.some((d) => d._key === key);
      if (!isDraft && !serverKeys.has(key) && !dirtyU.has(key)) {
        buffersRef.current.delete(key);
      }
    }
    syncList([...drafts, ...mapped]);
  }, [syncList]);

  /** 활성 버퍼를 Map에 flush */
  const flushActive = useCallback(() => {
    if (activeKey && activeBuffer) {
      buffersRef.current.set(activeKey, activeBuffer);
    }
  }, [activeBuffer, activeKey]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 신규 draft 행과 본문 버퍼를 추가하고 포커스한다
   *   2) 신규 버튼에서 호출한다
   *   3) 항상 새 _key를 반환한다
   */
  const addDraft = useCallback((
    listSeed: Omit<TList, "baseKey"> & { baseKey: string },
    buffer: TBuf,
  ) => {
    flushActive();
    const key = uid();
    buffersRef.current.set(key, buffer);
    const row = { ...listSeed, _key: key, _rowState: "C" as const } as EditableRow<TList>;
    syncList([...listRef.current, row]);
    setActiveKey(key);
    setActiveBuffer(buffer);
    bump();
    return key;
  }, [bump, flushActive, syncList]);

  const selectGen = useRef(0);

  /**
   * 개발자: 박승우
   * 일자: 2026-09-01
   * 코멘트:
   *   1) 행을 선택하고 버퍼를 활성으로 올린다. 버퍼가 없어도 ensureBuffer 는 호출한다(첨부 재조회)
   *   2) 좌측 그리드 onActivate에서 호출한다
   *   3) await 뒤 순번이 바뀌면 activeKey 를 쓰지 않는다. 같은 키를 다시 열면 flushActive 를 건너 저장 직후 버퍼를 덮지 않는다
   */
  const selectKey = useCallback(async (
    key: string | null,
    ensureBuffer?: (key: string, row: EditableRow<TList>) => Promise<TBuf | null>,
  ) => {
    // 같은 행을 다시 열 때(= 저장 직후 afterAll) React state 는 한 박자 늦다.
    // 방금 putBuffer 한 ref 를 빈 activeBuffer 로 덮지 않는다
    if (key !== activeKey) flushActive();
    if (!key) {
      selectGen.current += 1;
      setActiveKey(null);
      setActiveBuffer(null);
      return;
    }
    const row = listRef.current.find((r) => r._key === key);
    if (!row) return;
    const gen = ++selectGen.current;
    let buf: TBuf | null = buffersRef.current.get(key) ?? null;
    if (ensureBuffer) {
      const next = await ensureBuffer(key, row);
      if (selectGen.current !== gen) return;
      // 버퍼가 없을 때만 상세로 채운다. 있으면 미저장 편집을 덮지 않는다
      if (!buf && next) {
        buf = next;
        buffersRef.current.set(key, buf);
      }
    }
    if (selectGen.current !== gen) return;
    setActiveKey(key);
    setActiveBuffer(buf);
    bump();
  }, [activeKey, bump, flushActive]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 활성 본문 버퍼를 갱신하고 목록 행을 dirty로 표시한다
   *   2) 폼 onChange에서 호출한다
   *   3) C행은 C 유지, 저장행은 U
   */
  const patchActive = useCallback((
    updater: (prev: TBuf) => TBuf,
    listPatch?: Partial<TList>,
  ) => {
    if (!activeKey || !activeBuffer) return;
    const next = updater(activeBuffer);
    buffersRef.current.set(activeKey, next);
    setActiveBuffer(next);
    syncList(listRef.current.map((r) => {
      if (r._key !== activeKey) return r;
      return {
        ...r,
        ...listPatch,
        _rowState: r._rowState === "C" ? "C" : "U",
      } as EditableRow<TList>;
    }));
  }, [activeBuffer, activeKey, syncList]);

  /** 버퍼를 직접 교체 — 상세 API 적재 시 */
  const putBuffer = useCallback((key: string, buffer: TBuf, listPatch?: Partial<TList>) => {
    buffersRef.current.set(key, buffer);
    if (listPatch) {
      syncList(listRef.current.map((r) => (r._key === key ? { ...r, ...listPatch } as EditableRow<TList> : r)));
    }
    if (key === activeKey) setActiveBuffer(buffer);
    bump();
  }, [activeKey, bump, syncList]);

  const getDirty = useCallback(() => {
    flushActive();
    return listRef.current.filter((r) => r._rowState === "C" || r._rowState === "U");
  }, [flushActive]);

  const getBuffer = useCallback((key: string) => buffersRef.current.get(key) ?? null, []);

  const hasChanges = useCallback(
    () => listRef.current.some((r) => r._rowState === "C" || r._rowState === "U"),
    [],
  );

  useRegisterPageDirty(hasChanges);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) C draft만 로컬 제거한다
   *   2) 삭제 버튼·저장행이 아닐 때 호출한다
   *   3) 윗행으로 포커스를 옮긴다
   */
  const removeDraft = useCallback((key: string) => {
    const prev = listRef.current;
    const idx = prev.findIndex((r) => r._key === key);
    if (idx < 0) return null;
    const row = prev[idx];
    if (row._rowState !== "C") return null;
    buffersRef.current.delete(key);
    const next = prev.filter((r) => r._key !== key);
    syncList(next);
    const focus = next.length ? next[idx > 0 ? idx - 1 : 0] : null;
    setActiveKey(focus?._key ?? null);
    setActiveBuffer(focus?._key ? buffersRef.current.get(focus._key) ?? null : null);
    return focus?._key ?? null;
  }, [syncList]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) dirty 전건 검증 후 단건 저장을 순차 실행한다
   *   2) 저장 버튼에서 호출한다
   *   3) 신규 저장이면 서버 docIdx 로 activeKey 를 맞춘다 — 예전 버퍼의 docIdx(null)를 보면 키가 __new_* 에 고착된다
   */
  const saveAll = useCallback(async (args: {
    validate: (dirty: EditableRow<TList>[], getBuf: (key: string) => TBuf | null) => DocFormSessionValidateResult | null;
    saveOne: (row: EditableRow<TList>, buf: TBuf) => Promise<{ docIdx: number; listMeta?: Partial<TList> }>;
    afterAll?: () => Promise<void>;
  }): Promise<DocFormSessionValidateResult | null> => {
    flushActive();
    const dirty = listRef.current.filter((r) => r._rowState === "C" || r._rowState === "U");
    if (dirty.length === 0) {
      return { message: "저장할 변경 내용이 없습니다." };
    }
    const err = args.validate(dirty, (key) => buffersRef.current.get(key) ?? null);
    if (err) return err;

    // 활성 행이 저장되면 서버 키. remap 뒤 closure 의 예전 docIdx(신규면 null)를 쓰지 않는다
    let activeSavedDocIdx: number | null = null;
    for (const row of dirty) {
      const key = row._key;
      if (!key) continue;
      const buf = buffersRef.current.get(key);
      if (!buf) return { message: "편집 내용이 없습니다.", rowKey: key };
      const saved = await args.saveOne(row, buf);
      const nextBuf = { ...buf, docIdx: saved.docIdx } as TBuf;
      buffersRef.current.set(key, nextBuf);
      // C → 서버키로 교체 예약: afterAll 재조회에 맡기고 행은 일단 정리
      syncList(listRef.current.map((r) => {
        if (r._key !== key) return r;
        return {
          ...r,
          docIdx: saved.docIdx,
          ...saved.listMeta,
          _rowState: undefined,
        } as EditableRow<TList>;
      }));
      if (activeKey === key) {
        setActiveBuffer(nextBuf);
        if (saved.docIdx != null && saved.docIdx > 0) activeSavedDocIdx = saved.docIdx;
      }
    }

    // draft 키를 docIdx 키로 재매핑
    const remapped = new Map<string, TBuf>();
    for (const [key, buf] of buffersRef.current.entries()) {
      const docIdx = (buf as { docIdx?: number | null }).docIdx;
      if (docIdx != null && docIdx > 0) {
        remapped.set(String(docIdx), buf);
      } else {
        remapped.set(key, buf);
      }
    }
    buffersRef.current = remapped;

    // afterAll 보다 먼저 맞춘다. loadList 가 목록 키를 N 으로 바꿔도 patchActive 가 같은 키를 친다
    if (activeSavedDocIdx != null && activeSavedDocIdx > 0) {
      const nextKey = String(activeSavedDocIdx);
      setActiveKey(nextKey);
      setActiveBuffer(buffersRef.current.get(nextKey) ?? null);
    }

    if (args.afterAll) await args.afterAll();
    bump();
    return null;
  }, [activeKey, bump, flushActive, syncList]);

  /** 저장 후 서버 목록으로 교체할 때 dirty 버퍼 중 저장된 것만 정리 옵션 */
  const clearRowStates = useCallback(() => {
    syncList(listRef.current.map((r) => ({ ...r, _rowState: undefined } as EditableRow<TList>)));
  }, [syncList]);

  return {
    listRows,
    activeKey,
    activeBuffer,
    setActiveKey,
    addDraft,
    selectKey,
    patchActive,
    putBuffer,
    getDirty,
    getBuffer,
    hasChanges,
    removeDraft,
    saveAll,
    replaceServerList,
    clearRowStates,
    flushActive,
    buffersRef,
  };
}
