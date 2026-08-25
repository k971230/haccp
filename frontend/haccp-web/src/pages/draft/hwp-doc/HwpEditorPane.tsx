/**
 * HwpEditorPane — HWP 작성 화면의 우측 rhwp 편집기 패널.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) rhwp 편집기를 만들고, 열린 문서가 바뀔 때만 본문(또는 양식 원본)을 다시 연다
 *   2) HwpDraftPage 의 renderDetail 이 이 컴포넌트를 그린다 — 화면 슬롯이 같아 마운트가 유지된다
 *   3) 문서를 여는 일은 반드시 useEffect 에서 한다. 렌더 중에 부르면 실패할 때마다 다시 렌더되어
 *      같은 요청이 끝없이 나간다 (2026-08-25 문서 열기 실패 폭주의 원인)
 *
 * 편집기 인스턴스는 부모가 준 ref 에 올려 둔다 — 저장할 때 부모가 본문을 뽑아 올려야 한다.
 *
 * PIPELINE[HF182] HWP 작성 편집기 패널
 */
// 역할 — 편집기 수명·열기 상태
import { useEffect, useRef, useState, type MutableRefObject } from "react";
// 역할 — rhwp iframe 편집기
import { createEditor, type RhwpEditor } from "@rhwp/editor";
// 역할 — 스튜디오 주소·도구상자 접기·더티 감지
import {
  foldRhwpToolboxes,
  installRhwpEarlyFold,
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
}: {
  editorRef: MutableRefObject<RhwpEditor | null>;
  tmplCd: string;
  docIdx: number | null;
  canEdit: boolean;
  files: HtmlFormDraftFile[];
}) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const [ready, setReady] = useState(false);
  const [message, setMessage] = useState("rhwp 편집기를 준비하고 있습니다.");
  // 마지막으로 연 대상 — 같은 문서를 다시 열지 않는다. 실패한 대상도 기록해 재시도 폭주를 막는다
  const openedRef = useRef<string>("");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) rhwp 편집기를 한 번만 만들고 화면을 떠날 때 정리한다
   *   2) 패널이 마운트될 때 실행한다
   *   3) 옵션은 기존 HWP 편집 화면과 같게 둔다 — 렌더러가 갈리면 두 화면이 달라 보인다
   */
  useEffect(() => {
    const host = hostRef.current;
    if (!host) return undefined;
    let disposed = false;
    const disposeEarlyFold = installRhwpEarlyFold(host);

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
        foldRhwpToolboxes(created.element);
        editorRef.current = created;
        setReady(true);
        setMessage("왼쪽에서 문서를 고르거나 「행 추가」를 눌러 작성하세요.");
      } catch (error) {
        if (!disposed) setMessage(toUserMessage(error));
      }
    })();

    return () => {
      disposed = true;
      disposeEarlyFold();
      editorRef.current?.destroy();
      editorRef.current = null;
    };
  }, [editorRef]);

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
    if (!ready || !editor || !tmplCd) return;
    const src = latestSource(files);
    // 문서·양식·본문 조합이 같으면 다시 열지 않는다. 사용자가 쓰던 내용이 날아가면 안 된다
    const token = `${docIdx ?? 0}:${tmplCd}:${src?.idx ?? 0}`;
    if (openedRef.current === token) return;
    openedRef.current = token;

    void (async () => {
      try {
        if (src) {
          const blob = await downloadDocumentFile(src.idx);
          await editor.loadFile(await blob.arrayBuffer(), src.fileNm, {
            skipUnsavedGuard: true,
            suppressDialogs: true,
          });
          setMessage(`${src.fileNm} 을(를) 열었습니다.`);
          return;
        }
        // 본문이 아직 없을 때(= 첫 작성) 양식 원본을 연다
        const tmpl = (await listDocumentTemplates()).find((t) => t.tmplCd === tmplCd);
        if (!tmpl?.formUrl) {
          setMessage("이 양식의 원본 파일이 없습니다. 사용양식 관리에서 양식을 올리세요.");
          return;
        }
        const buffer = await loadHwpTemplateFile(tmpl.formUrl);
        await editor.loadFile(buffer, tmpl.formFileNm || `${tmplCd}.hwp`, {
          skipUnsavedGuard: true,
          suppressDialogs: true,
        });
        setMessage(`${tmpl.tmplNm} 양식을 열었습니다.`);
      } catch (error) {
        // 토스트를 띄우지 않는다 — 같은 문서에서 여러 번 뜨면 화면이 가려진다. 상태 줄로만 알린다
        setMessage(toUserMessage(error));
      }
    })();
  }, [docIdx, editorRef, files, ready, tmplCd]);

  return (
    <div className="flex h-full min-h-0 flex-col">
      <p
        // 편집기 상태 한 줄 — 무엇이 열렸는지 항상 보이게 둔다
        className="shrink-0 border-b border-slate-200 px-3 py-1.5 text-xs text-slate-500"
      >
        {tmplCd
          ? message
          : "왼쪽에서 문서를 고르거나 「행 추가」를 눌러 작성하세요."}
        {tmplCd && !canEdit ? " (저장 전이거나 전송한 문서라 편집할 수 없습니다.)" : ""}
      </p>
      <div
        // rhwp iframe 호스트 — 남은 높이 전부
        ref={hostRef}
        className="min-h-0 flex-1"
      />
    </div>
  );
}
