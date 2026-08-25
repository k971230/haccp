/**
 * HwpDraftPage — HWP 양식 작성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 공통 HtmlFormDraftPage 에 rhwp 편집기·오늘 할일 팝업·본문 업로드만 얹는다.
 *      검색·목록·행 추가·저장·전송·삭제·전송취소는 HTML 작성 5화면과 같은 코드가 처리한다
 *   2) 우측이 지면(Paper)이 아니라 rhwp 라서 renderDetail 로 그린다 — 그 자리만 다르고 나머지는 형제 화면과 같다
 *   3) 본문은 문서 첨부(HWP_SRC)로 오간다. 저장하면 rhwp 에서 뽑아 올리고, 열면 내려받아 연다
 *
 * 양식 파일·PDF 변환은 기존 HWP 편집 화면과 같은 API 를 쓴다. 새 경로를 만들지 않는다.
 *
 * PIPELINE[HF182] HWP 작성 화면
 */
// 역할 — 편집기 수명·상태
import { useCallback, useEffect, useRef, useState } from "react";
// 역할 — rhwp iframe 편집기
import { createEditor, type RhwpEditor } from "@rhwp/editor";
// 역할 — 스튜디오 주소·도구상자 접기·더티 감지
import {
  foldRhwpToolboxes,
  installRhwpDirtyListeners,
  installRhwpEarlyFold,
  resolveRhwpStudioUrl,
} from "@/lib/rhwpStudio";
// 역할 — 양식 원본·문서 첨부 입출력 (기존 HWP 화면과 같은 API)
import {
  downloadDocumentFile,
  listDocumentTemplates,
  loadHwpTemplateFile,
  uploadDocumentFile,
} from "@/api/documentApi";
// 역할 — 오늘 할일 조회
import { hwpDraftApi, listHwpDraftTasks, type HwpDraftTask } from "@/api/draft/hwpDraftApi";
// 역할 — 양식 작성 공통 화면
import { HtmlFormDraftPage, type HtmlFormDraftPick } from "../HtmlFormDraftPage";
// 역할 — 오늘 할일 선택 팝업
import { HwpTaskLookupModal } from "../HwpTaskLookupModal";
// 역할 — 업무 오류
import { mesError } from "@/shell/errors";
// 역할 — 안내 토스트
import { mesToast } from "@/shell/dialog";
// 역할 — 이 화면 상수
import {
  HWP_SRC_KIND,
  PAPER_SUBTITLE,
  PAPER_TITLE,
  PERSIST_ID,
  SCRN_CD,
  SPLIT_KEY,
} from "./HwpDraftRule";

/** 저장 파일명 — {YYYY-MM-DD}_{양식명}_{연번}. 서버가 연번을 다시 매기므로 001 로 보낸다 */
function hwpFileName(baseKey: string, tmplNm: string, ext: string): string {
  const date = baseKey.length === 8
    ? `${baseKey.slice(0, 4)}-${baseKey.slice(4, 6)}-${baseKey.slice(6, 8)}`
    : baseKey;
  const safe = (tmplNm || "문서").replace(/[^0-9A-Za-z가-힣._() -]/g, "_").trim();
  return `${date}_${safe}_001${ext}`;
}

export function HwpDraftPage() {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const editorRef = useRef<RhwpEditor | null>(null);
  const [editorReady, setEditorReady] = useState(false);
  const [message, setMessage] = useState("rhwp 편집기를 준비하고 있습니다.");
  // 오늘 할일 팝업 — 행 추가가 열고, 고르거나 취소하면 약속을 이행한다
  const [tasks, setTasks] = useState<HwpDraftTask[] | null>(null);
  const pickResolveRef = useRef<((pick: HtmlFormDraftPick | null) => void) | null>(null);
  // 마지막으로 연 문서·양식 — 같은 것을 두 번 열지 않는다
  const openedRef = useRef<string>("");
  // 저장 때 쓸 파일명 재료 — renderDetail 이 매번 채운다
  const nameRef = useRef<{ baseKey: string; tmplNm: string }>({ baseKey: "", tmplNm: "" });

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) rhwp 편집기를 한 번만 만들고 화면이 닫힐 때 정리한다
   *   2) 화면 진입에서 실행한다
   *   3) 기존 HWP 편집 화면과 같은 옵션을 쓴다 — 렌더러·도구상자 접기가 갈리면 두 화면이 달라 보인다
   */
  useEffect(() => {
    const host = hostRef.current;
    if (!host) return undefined;
    let disposed = false;
    let created: RhwpEditor | null = null;
    let disposeDirty: (() => void) | undefined;
    const disposeEarlyFold = installRhwpEarlyFold(host);

    void (async () => {
      try {
        created = await createEditor(host, {
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
        disposeDirty = installRhwpDirtyListeners(created.element, () => undefined);
        editorRef.current = created;
        setEditorReady(true);
        setMessage("왼쪽에서 문서를 고르거나 「행 추가」를 눌러 작성하세요.");
      } catch (error) {
        if (!disposed) {
          setMessage(error instanceof Error ? error.message : "rhwp 편집기를 시작하지 못했습니다.");
        }
      }
    })();

    return () => {
      disposed = true;
      disposeEarlyFold();
      disposeDirty?.();
      editorRef.current?.destroy();
      editorRef.current = null;
    };
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 저장된 본문이 있으면 그것을, 없으면 양식 원본을 편집기에 연다
   *   2) 좌측에서 행을 고르거나 양식을 고르면 호출한다
   *   3) 같은 문서를 다시 열지 않는다 — 열 때마다 사용자가 쓰던 내용이 날아가면 안 된다
   */
  const openInEditor = useCallback(async (
    // docIdx: 저장된 문서 idx. 없으면 양식 원본을 연다
    docIdx: number | null,
    // tmplCd: 양식코드
    tmplCd: string,
    // files: 문서 첨부 목록
    files: { fileIdx: number; fileKind: string; fileNm: string }[],
  ) => {
    const editor = editorRef.current;
    if (!editor) return;
    const token = `${docIdx ?? 0}:${tmplCd}`;
    if (openedRef.current === token) return;
    try {
      // 저장된 본문 중 가장 나중 것 — 여러 번 저장하면 첨부가 쌓인다
      const sources = files.filter((f) => f.fileKind === HWP_SRC_KIND);
      const src = sources.length > 0 ? sources[sources.length - 1] : null;
      if (src) {
        const blob = await downloadDocumentFile(src.fileIdx);
        await editor.loadFile(await blob.arrayBuffer(), src.fileNm, {
          skipUnsavedGuard: true,
          suppressDialogs: true,
        });
        openedRef.current = token;
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
      openedRef.current = token;
      setMessage(`${tmpl.tmplNm} 양식을 열었습니다.`);
    } catch (error) {
      mesError(error);
    }
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 저장이 끝나면 편집기 내용을 본문 파일로 올린다
   *   2) 공통 화면이 좌측·우측 저장 뒤에 호출한다
   *   3) 편집기가 아직 없으면 아무것도 올리지 않는다 — 좌측 저장만 한 경우다
   */
  const uploadBody = useCallback(async (
    // docIdx: 방금 저장된 문서 idx
    docIdx: number,
  ) => {
    const editor = editorRef.current;
    if (!editor) return;
    const bytes = await editor.exportHwpx();
    const { baseKey, tmplNm } = nameRef.current;
    const fileNm = hwpFileName(baseKey, tmplNm, ".hwpx");
    await uploadDocumentFile(docIdx, HWP_SRC_KIND, new File([Uint8Array.from(bytes)], fileNm, {
      type: "application/vnd.hancom.hwpx",
    }));
    // 방금 올린 본문을 다음 조회에서 다시 열도록 표식을 지운다
    openedRef.current = "";
    try {
      await editor.notifySaved(fileNm);
    } catch {
      // 저장 통지는 편집기 표시용이라 실패해도 업무를 막지 않는다
    }
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 행 추가 직전에 오늘 할일 팝업을 띄우고 고른 값을 돌려준다
   *   2) 공통 화면의 행 추가가 호출한다
   *   3) 할일이 없으면 팝업 없이 바로 null — 사용자가 빈 팝업을 닫는 수고를 없앤다
   */
  const pickBeforeAdd = useCallback(async (): Promise<HtmlFormDraftPick | null> => {
    let list: HwpDraftTask[] = [];
    try {
      list = await listHwpDraftTasks();
    } catch (error) {
      mesError(error);
      return null;
    }
    if (list.length === 0) {
      mesToast("오늘 처리할 HWP 문서주기가 없습니다. 양식을 직접 고르세요.", "info");
      return null;
    }
    setTasks(list);
    return new Promise<HtmlFormDraftPick | null>((resolve) => {
      pickResolveRef.current = resolve;
    });
  }, []);

  /** 팝업 응답 — 고르거나 취소하면 행 추가가 이어진다 */
  const answerPick = useCallback((pick: HtmlFormDraftPick | null) => {
    setTasks(null);
    pickResolveRef.current?.(pick);
    pickResolveRef.current = null;
  }, []);

  return (
    <>
      <HtmlFormDraftPage
        // 화면코드 — tbl_screen.scrn_cd. 권한·그리드 pref·API 베이스 기준
        scrnCd={SCRN_CD}
        // 열 너비 저장 키
        persistId={PERSIST_ID}
        // 좌우 분할 비율 저장 키
        splitKey={SPLIT_KEY}
        // 지면 제목 — 양식명이 없을 때만 쓴다
        paperTitle={PAPER_TITLE}
        // 지면 부제
        paperSubtitle={PAPER_SUBTITLE}
        // 작성 API — /api/v1/draft/hwp-doc/hwp-write
        api={hwpDraftApi}
        // 행 추가 전 오늘 할일 팝업 — 취소하면 양식 선택 팝업으로 이어진다
        pickBeforeAdd={pickBeforeAdd}
        // 저장 뒤 본문 업로드 — 이 화면만 파일이 따로 있다
        afterSave={uploadBody}
        // 우측 — 지면 대신 rhwp 편집기
        renderDetail={({ buf, docIdx, canEdit, files }) => {
          // 파일명 재료를 갱신해 둔다 — 저장 시점에 다시 계산하면 활성 행이 바뀌어 있을 수 있다
          nameRef.current = { baseKey: buf?.baseKey ?? "", tmplNm: buf?.tmplNm ?? "" };
          if (buf?.tmplCd && editorReady) {
            void openInEditor(docIdx, buf.tmplCd, files);
          }
          return (
            <div className="flex h-full min-h-0 flex-col">
              <p
                // 편집기 상태 한 줄 — 무엇이 열렸는지 항상 보이게 둔다
                className="shrink-0 border-b border-slate-200 px-3 py-1.5 text-xs text-slate-500"
              >
                {buf?.tmplCd
                  ? message
                  : "왼쪽에서 문서를 고르거나 「행 추가」를 눌러 작성하세요."}
                {buf?.tmplCd && !canEdit ? " (저장 전이거나 전송한 문서라 편집할 수 없습니다.)" : ""}
              </p>
              <div
                // rhwp iframe 호스트 — 남은 높이 전부
                ref={hostRef}
                className="min-h-0 flex-1"
              />
            </div>
          );
        }}
      />
      {tasks ? (
        <HwpTaskLookupModal
          scrnCd={SCRN_CD}
          tasks={tasks}
          // 고른 할일의 양식·기준일로 행을 채운다
          onSelect={(task) => answerPick({
            tmplCd: task.tmplCd,
            tmplNm: task.tmplNm,
            baseDt: task.baseDt,
            docIdx: task.docIdx ?? null,
          })}
          // 취소 — 빈 행만 추가하고 양식 선택 팝업으로 넘어간다
          onSkip={() => answerPick(null)}
        />
      ) : null}
    </>
  );
}
