/**
 * HwpEditorPane — HWP 작성 화면의 우측 rhwp 편집기 패널.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 마운트는 RhwpStudioHost 에 맡기고, 열린 문서가 바뀔 때만 본문(또는 양식 원본)을 다시 연다
 *   2) HwpDraftPage 의 renderDetail 이 이 컴포넌트를 그린다 — 화면 슬롯이 같아 마운트가 유지된다
 *   3) 저장된 문서에 첨부가 없으면 양식 원본을 열지 않는다. loadFile 은 한 줄 직렬
 *      CanvasView 「페이지 0 정보가 없습니다」는 @rhwp/editor 번들 로그다. 호스트 가드로 줄인다.
 *
 * 편집기 인스턴스는 부모가 준 ref 에 올려 둔다 — 저장할 때 부모가 본문을 뽑아 올려야 한다.
 *
 * PIPELINE[HF182] HWP 작성 편집기 패널
 */
// 역할 — 열기 상태
import { useCallback, useEffect, useRef, useState, type MutableRefObject } from "react";
// 역할 — rhwp 편집기 타입
import type { RhwpEditor } from "@rhwp/editor";
// 역할 — rhwp 마운트 공통 — 도구상자는 호스트가 접지 않는다
import { RhwpStudioHost } from "@/components/document/RhwpStudioHost";
// 역할 — 더티 감지
import { installRhwpDirtyListeners } from "@/lib/rhwpStudio";
// 역할 — 양식 원본·문서 첨부 읽기 (기존 HWP 화면과 같은 API)
import {
  downloadDocumentFile,
  listDocumentTemplates,
  loadHwpTemplateFile,
} from "@/api/documentApi";
// 역할 — 첨부 계약
import type { HtmlFormDraftFile } from "@/api/draft/htmlFormDraftTypes";
// 역할 — 업무 오류 문구
import { toUserMessage } from "@/shell/errors";
// 역할 — 본문 파일 종류
import { HWP_SRC_KIND } from "./HwpDraftRule";
// 역할 — 저장 문서에 첨부가 없을 때 양식 원본 금지
import { hwpOpenMode, type HwpOpenMode } from "./hwpOpenMode";

/** 첨부 중 가장 나중에 올린 본문 — 여러 번 저장하면 첨부가 쌓인다 */
function latestSource(files: HtmlFormDraftFile[]): HtmlFormDraftFile | null {
  const sources = files.filter((f) => f.fileKind === HWP_SRC_KIND);
  return sources.length > 0 ? sources[sources.length - 1] : null;
}

export function HwpEditorPane({
  // editorRef: 부모가 저장 때 쓰는 편집기 참조
  editorRef,
  // tmplCd: 열린 문서의 양식코드. 비면 아직 고른 양식이 없다
  tmplCd,
  // docIdx: 저장된 문서 idx. 없으면 양식 원본을 연다
  docIdx,
  // canEdit: 우측을 고칠 수 있는 상태인지
  canEdit,
  // files: 문서 첨부 목록 — 본문을 여기서 찾는다
  files,
  // onDirty: 칸 입력·붙여넣기 때 본문 dirty. 목록 patchActive 는 부르지 않는다
  onDirty,
  // onClean: loadFile 성공 뒤 dirty 해제 — 로드 키입력이 본문 변경으로 안 보이게
  onClean,
  // onOpened: 편집기가 지금 무엇을 들고 있는지 부모에게 알린다. 저장 가드가 이걸 본다
  onOpened,
  // readOnly: 결재 미리보기 — 저장 경로가 없는 화면. 상태 줄 문구만 바뀐다
  readOnly = false,
}: {
  editorRef: MutableRefObject<RhwpEditor | null>;
  tmplCd: string;
  docIdx: number | null;
  canEdit: boolean;
  files: HtmlFormDraftFile[];
  onDirty?: () => void;
  onClean?: () => void;
  onOpened?: (mode: HwpOpenMode, docIdx: number | null) => void;
  readOnly?: boolean;
}) {
  const [ready, setReady] = useState(false);
  const [message, setMessage] = useState("rhwp 편집기를 준비하고 있습니다.");
  // 마지막으로 연 대상 — 같은 문서를 다시 열지 않는다. 실패한 대상도 기록해 재시도 폭주를 막는다
  const openedRef = useRef<string | null>("");
  // 리스너·콜백은 최신값을 본다 — 호스트 마운트를 다시 돌리지 않으려고 ref 에 둔다
  const canEditRef = useRef(canEdit);
  canEditRef.current = canEdit;
  const onDirtyRef = useRef(onDirty);
  onDirtyRef.current = onDirty;
  const onCleanRef = useRef(onClean);
  onCleanRef.current = onClean;
  /*
   * onOpened 도 ref 에 둔다. 아래 열기 효과의 의존에 넣으면 부모가 리렌더할 때마다
   * 효과가 다시 돌아 파일을 다시 열고 — 사용자가 쓰던 내용을 날린다.
   */
  const onOpenedRef = useRef(onOpened);
  onOpenedRef.current = onOpened;
  // readOnly 도 ref 로 읽는다 — 의존에 넣으면 효과가 다시 돌아 파일을 다시 연다(쓰던 내용이 날아간다)
  const readOnlyRef = useRef(readOnly);
  readOnlyRef.current = readOnly;
  // dirty 리스너 해제 — 파일을 다시 열면 iframe 문서가 바뀌어 다시 붙인다
  const disposeDirtyRef = useRef<(() => void) | undefined>(undefined);
  // loadFile 은 취소가 없다. 한 줄로 직렬화한다
  const loadQueue = useRef(Promise.resolve());
  const filesRef = useRef(files);
  filesRef.current = files;
  const docIdxRef = useRef(docIdx);
  docIdxRef.current = docIdx;
  const tmplCdRef = useRef(tmplCd);
  tmplCdRef.current = tmplCd;

  const attachDirty = useCallback((iframe: HTMLIFrameElement | null | undefined) => {
    disposeDirtyRef.current?.();
    disposeDirtyRef.current = installRhwpDirtyListeners(iframe, () => {
      // 편집 불가일 때(= 저장 전·전송 이후) 본문 dirty 로 올리지 않는다
      if (!canEditRef.current) return;
      onDirtyRef.current?.();
    });
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-09-03
   * 코멘트:
   *   1) RhwpStudioHost 가 편집기를 만든 뒤 dirty 를 붙이고 열기 효과를 연다
   *   2) 호스트 onReady 에서 호출한다
   *   3) SDK 에 dirty API 가 없어 iframe DOM 으로 본다
   */
  const handleHostReady = useCallback(() => {
    attachDirty(editorRef.current?.element);
    setReady(true);
    setMessage("왼쪽에서 문서를 고르거나 「행추가」를 눌러 작성하세요.");
  }, [attachDirty, editorRef]);

  useEffect(() => () => {
    disposeDirtyRef.current?.();
    disposeDirtyRef.current = undefined;
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-09-01
   * 코멘트:
   *   1) 열린 문서가 바뀌면 저장된 본문을 싣는다. 첨부가 올 때까지 양식 원본은 열지 않는다
   *   2) 좌측에서 행을 고르거나 양식을 고르면 이 효과가 다시 돈다
   *   3) loadFile 은 한 줄 직렬. 큐에서 꺼냈을 때 표식이 아니면 호출하지 않고, 끝난 뒤 바뀌었으면 지금 표식을 다시 연다
   */
  useEffect(() => {
    const editor = editorRef.current;
    if (!ready || !editor || !tmplCd) return undefined;
    const src = latestSource(files);
    const mode = hwpOpenMode(docIdx, !!src);
    // 저장된 문서인데 본문이 아직 없으면 빈 양식을 열지 않는다
    if (mode === "wait") {
      openedRef.current = `${docIdx}:${tmplCd}:wait`;
      // 저장된 문서인데 본문이 아직 없다 — 편집기 내용은 이 문서 것이 아니다
      onOpenedRef.current?.("wait", docIdx);
      /*
       * 결재 미리보기(readOnly)에서는 「여는 중」이 거짓말이다.
       *
       * 이 화면에는 본문을 올릴 방법이 없어서 기다려도 아무 일이 안 일어난다.
       * 결재자가 빈 화면을 하염없이 보다가 그냥 승인한다 — 실제로 본문 없는 문서가
       * 결재완료까지 갔다. 무엇을 보고 있는지 말해 준다.
       * (새 문서는 sp_tbl_document_approval_c_000 가드가 막는다. 이건 그 전에 넘어간 것들이다.)
       */
      setMessage(readOnlyRef.current
        ? "본문이 저장되지 않은 문서입니다. 작성 화면에서 본문을 저장해야 내용이 보입니다."
        : "문서를 여는 중입니다…");
      return undefined;
    }
    // 문서·양식·본문 조합이 같으면 다시 열지 않는다. 사용자가 쓰던 내용이 날아가면 안 된다
    const token = `${docIdx ?? 0}:${tmplCd}:${src?.idx ?? 0}`;
    if (openedRef.current === token) return undefined;
    openedRef.current = token;

    let alive = true;
    /*
     * 읽기 전에 먼저 잠근다. 성공했을 때만 푼다.
     *
     * 여기서 안 잠그면 「로드 중」 창이 남는다 — 행 A 를 열어 둔 채 행 B 를 누르면
     * 로드가 끝날 때까지 편집기에는 A 가 있고, 그때 저장하면 A 의 본문이 B 로 올라간다.
     * 토큰이 같아 위에서 이미 돌아간 경우(= 같은 문서 재렌더)는 여기 오지 않으므로
     * 열려 있던 상태를 잘못 되돌리지 않는다.
     */
    onOpenedRef.current?.("wait", docIdx);
    setMessage("문서를 여는 중입니다…");

    const loadToken = async (want: string) => {
      if (!alive || openedRef.current !== want) return;
      const currentSrc = latestSource(filesRef.current);
      const currentTmpl = tmplCdRef.current;
      const currentDoc = docIdxRef.current;
      const currentMode = hwpOpenMode(currentDoc, !!currentSrc);
      if (currentMode === "wait") {
        setMessage("문서를 여는 중입니다…");
        return;
      }
      const nowToken = `${currentDoc ?? 0}:${currentTmpl}:${currentSrc?.idx ?? 0}`;
      if (nowToken !== want) return;
      try {
        if (currentSrc) {
          const blob = await downloadDocumentFile(currentSrc.idx);
          if (!alive || openedRef.current !== want) return;
          const buf = await blob.arrayBuffer();
          if (!alive || openedRef.current !== want) return;
          await editor.loadFile(buf, currentSrc.fileNm, {
            skipUnsavedGuard: true,
            suppressDialogs: true,
          });
          if (!alive) return;
          if (openedRef.current !== want) {
            await loadToken(openedRef.current ?? "");
            return;
          }
          attachDirty(editor.element);
          onCleanRef.current?.();
          // 이 자리라야 한다. 위 재귀 로드 분기보다 앞에서 알리면 방금 버린 문서를 「열렸다」고 올린다
          onOpenedRef.current?.("source", currentDoc);
          setMessage(`${currentSrc.fileNm} 을(를) 열었습니다.`);
          return;
        }
        const tmpl = (await listDocumentTemplates()).find((t) => t.tmplCd === currentTmpl);
        if (!alive || openedRef.current !== want) return;
        if (!tmpl?.formUrl) {
          setMessage("이 양식의 원본 파일이 없습니다. 사용양식 관리에서 양식을 올리세요.");
          return;
        }
        const buffer = await loadHwpTemplateFile(tmpl.formUrl);
        if (!alive || openedRef.current !== want) return;
        await editor.loadFile(buffer, tmpl.formFileNm || `${currentTmpl}.hwp`, {
          skipUnsavedGuard: true,
          suppressDialogs: true,
        });
        if (!alive) return;
        if (openedRef.current !== want) {
          await loadToken(openedRef.current ?? "");
          return;
        }
        attachDirty(editor.element);
        onCleanRef.current?.();
        onOpenedRef.current?.("template", currentDoc);
        setMessage(`${tmpl.tmplNm} 양식을 열었습니다.`);
      } catch (error) {
        if (alive && openedRef.current === want) setMessage(toUserMessage(error));
      }
    };

    loadQueue.current = loadQueue.current.then(
      () => loadToken(token),
      () => loadToken(token),
    );

    return () => {
      alive = false;
      if (openedRef.current === token) openedRef.current = null;
    };
  }, [attachDirty, docIdx, editorRef, files, ready, tmplCd]);

  return (
    <div className="flex h-full min-h-0 flex-col">
      <p
        // 편집기 상태 한 줄 — 무엇이 열렸는지 항상 보이게 둔다
        className="shrink-0 border-b border-slate-200 px-3 py-1.5 text-xs text-slate-500"
      >
        {tmplCd
          ? message
          : "왼쪽에서 문서를 고르거나 「행추가」를 눌러 작성하세요."}
        {/* ponytail: rhwp SDK 에 읽기전용 모드가 없어 문구로만 알린다.
            진짜 잠금이 필요해지면 서버 PDF(exportDocumentPdf) 임베드로 바꾼다 */}
        {tmplCd && readOnly
          ? " (읽기 전용 — 이 화면에서 고친 내용은 저장되지 않습니다.)"
          : tmplCd && !canEdit ? " (저장 전이거나 전송한 문서라 편집할 수 없습니다.)" : ""}
      </p>
      <RhwpStudioHost
        // 편집기 인스턴스 — 호스트가 만들고 이 패널이 loadFile 에 쓴다
        editorRef={editorRef}
        // 마운트 성공 — dirty 를 붙이고 문서 열기를 연다
        onReady={handleHostReady}
        // 마운트 실패 — 상태 줄에 업무 문구
        onError={(error) => setMessage(toUserMessage(error))}
      />
    </div>
  );
}
