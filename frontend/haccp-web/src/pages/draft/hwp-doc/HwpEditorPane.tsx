/**
 * HwpEditorPane — HWP 작성 화면의 우측 rhwp 편집기 패널.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) rhwp 편집기를 만들고, 열린 문서가 바뀔 때만 본문(또는 양식 원본)을 다시 연다
 *   2) HwpDraftPage 의 renderDetail 이 이 컴포넌트를 그린다 — 화면 슬롯이 같아 마운트가 유지된다
 *   3) 칸 입력 dirty 는 목록 _rowState 가 아니다. 골드 HwpDocumentEditorPage 와 같이
 *      installRhwpDirtyListeners 로만 알린다. 문서를 여는 일은 반드시 useEffect 에서 한다
 *      (렌더 중에 부르면 실패할 때마다 다시 렌더되어 같은 요청이 끝없이 나간다)
 *
 * 편집기 인스턴스는 부모가 준 ref 에 올려 둔다 — 저장할 때 부모가 본문을 뽑아 올려야 한다.
 *
 * PIPELINE[HF182] HWP 작성 편집기 패널
 */
// 역할 — 편집기 수명·열기 상태
import { useCallback, useEffect, useRef, useState, type MutableRefObject } from "react";
// 역할 — rhwp iframe 편집기
import { createEditor, type RhwpEditor } from "@rhwp/editor";
// 역할 — 스튜디오 주소·더티 감지
import {
  installRhwpDirtyListeners,
  resolveRhwpStudioUrl,
} from "@/lib/rhwpStudio";
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
  readOnly?: boolean;
}) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const [ready, setReady] = useState(false);
  const [message, setMessage] = useState("rhwp 편집기를 준비하고 있습니다.");
  // 마지막으로 연 대상 — 같은 문서를 다시 열지 않는다. 실패한 대상도 기록해 재시도 폭주를 막는다
  const openedRef = useRef<string | null>("");
  // 리스너·콜백은 최신값을 본다 — createEditor 효과를 다시 돌리지 않으려고 ref 에 둔다
  const canEditRef = useRef(canEdit);
  canEditRef.current = canEdit;
  const onDirtyRef = useRef(onDirty);
  onDirtyRef.current = onDirty;
  const onCleanRef = useRef(onClean);
  onCleanRef.current = onClean;
  // dirty 리스너 해제 — 파일을 다시 열면 iframe 문서가 바뀌어 다시 붙인다
  const disposeDirtyRef = useRef<(() => void) | undefined>(undefined);

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
   * 일자: 2026-08-25
   * 코멘트:
   *   1) rhwp 편집기를 한 번만 만들고 화면을 떠날 때 정리한다
   *   2) 패널이 마운트될 때 실행한다
   *   3) 골드와 같은 dirty 리스너를 iframe 에 붙인다 — SDK 에 dirty API 가 없어 DOM 으로 본다
   */
  useEffect(() => {
    const host = hostRef.current;
    if (!host) return undefined;
    let disposed = false;
    /*
     * 도구상자를 접지 않는다.
     *
     * 이 화면은 사람이 한글 문서를 **직접 고치는** 곳이다. 글꼴·표·정렬을 쓸 수 없으면
     * 일지를 채울 방법이 없다 — 「도구함이 없어 쓰기 어렵다」는 보고가 그것이다.
     * 미리보기 화면(사용양식관리)은 고칠 일이 없어 거기서만 접는다.
     */

    void (async () => {
      try {
        const created = await createEditor(host, {
          // 동일출처 스튜디오 — /rhwp 프록시
          studioUrl: resolveRhwpStudioUrl(),
          width: "100%",
          height: "100%",
          // HACCP 문서는 호환 우선 Canvas2D 렌더러
          renderer: "canvas2d",
        });
        if (disposed) {
          created.destroy();
          return;
        }
        attachDirty(created.element);
        editorRef.current = created;
        setReady(true);
        setMessage("왼쪽에서 문서를 고르거나 「행추가」를 눌러 작성하세요.");
      } catch (error) {
        if (!disposed) setMessage(toUserMessage(error));
      }
    })();

    return () => {
      disposed = true;
      disposeDirtyRef.current?.();
      disposeDirtyRef.current = undefined;
      editorRef.current?.destroy();
      editorRef.current = null;
    };
  }, [attachDirty, editorRef]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 열린 문서가 바뀌면 저장된 본문을, 없으면 양식 원본을 편집기에 싣는다
   *   2) 좌측에서 행을 고르거나 양식을 고르면 이 효과가 다시 돈다
   *   3) 대상 표식을 요청 전에 먼저 남긴다 — 실패해도 같은 대상을 다시 부르지 않는다
   */
  useEffect(() => {
    const editor = editorRef.current;
    if (!ready || !editor || !tmplCd) return undefined;
    const src = latestSource(files);
    // 문서·양식·본문 조합이 같으면 다시 열지 않는다. 사용자가 쓰던 내용이 날아가면 안 된다
    const token = `${docIdx ?? 0}:${tmplCd}:${src?.idx ?? 0}`;
    if (openedRef.current === token) return undefined;
    openedRef.current = token;

    /*
     * 늦게 온 응답이 화면을 덮지 않게 한다.
     *
     * HWP 는 내려받기와 loadFile 둘 다 느리다. 목록에서 문서를 빠르게 바꾸면
     * 먼저 시작한 A 의 loadFile 이 나중에 끝나 B 위에 A 가 실린다 —
     * 「다른 파일이 열린다」로 보고된 것이 이것이다.
     * await 마다 표식이 아직 내 것인지 확인하고, 아니면 조용히 그만둔다.
     * (HtmlDocumentPreview 가 쓰는 alive 패턴과 같은 것이다)
     */
    let alive = true;
    const mine = () => alive && openedRef.current === token;

    // 여는 동안 앞 문서 이름이 남아 있으면 다른 파일이 열린 것처럼 보인다
    setMessage("문서를 여는 중입니다…");

    void (async () => {
      try {
        if (src) {
          const blob = await downloadDocumentFile(src.idx);
          if (!mine()) return;
          const buf = await blob.arrayBuffer();
          if (!mine()) return;
          await editor.loadFile(buf, src.fileNm, {
            skipUnsavedGuard: true,
            suppressDialogs: true,
          });
          if (!mine()) return;
          attachDirty(editor.element);
          onCleanRef.current?.();
          setMessage(`${src.fileNm} 을(를) 열었습니다.`);
          return;
        }
        // 본문이 아직 없을 때(= 첫 작성) 양식 원본을 연다
        const tmpl = (await listDocumentTemplates()).find((t) => t.tmplCd === tmplCd);
        if (!mine()) return;
        if (!tmpl?.formUrl) {
          setMessage("이 양식의 원본 파일이 없습니다. 사용양식 관리에서 양식을 올리세요.");
          return;
        }
        const buffer = await loadHwpTemplateFile(tmpl.formUrl);
        if (!mine()) return;
        await editor.loadFile(buffer, tmpl.formFileNm || `${tmplCd}.hwp`, {
          skipUnsavedGuard: true,
          suppressDialogs: true,
        });
        if (!mine()) return;
        attachDirty(editor.element);
        onCleanRef.current?.();
        setMessage(`${tmpl.tmplNm} 양식을 열었습니다.`);
      } catch (error) {
        // 토스트를 띄우지 않는다 — 같은 문서에서 여러 번 뜨면 화면이 가려진다. 상태 줄로만 알린다
        if (mine()) setMessage(toUserMessage(error));
      }
    })();

    return () => {
      alive = false;
      /*
       * 표식을 되돌린다 — 중간에 그만둔 문서는 「연 적 없음」이어야 한다.
       * 안 그러면 사용자가 A → B → A 로 돌아왔을 때 A 가 이미 열린 것으로 보여 빈 편집기가 남는다.
       */
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
      <div
        // rhwp iframe 호스트 — 남은 높이 전부
        ref={hostRef}
        className="min-h-0 flex-1"
      />
    </div>
  );
}
