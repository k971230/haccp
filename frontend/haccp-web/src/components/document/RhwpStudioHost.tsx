/**
 * RhwpStudioHost — rhwp 편집기 마운트만 담당하는 공통 호스트.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) createEditor·호스트 크기·언마운트 destroy 를 한 곳에서 한다. 도구상자는 접지 않는다
 *   2) 작성(HwpEditorPane)·사용양식관리가 이 컴포넌트를 쓴다. 버튼·열기·저장은 화면이 가진다
 *   3) 호스트 높이가 0인 채로 붙이면 CanvasView 가 「페이지 0 정보가 없습니다」를 남긴다
 *
 * PIPELINE[HF182] 연관 — rhwp 마운트 공통
 */
// 역할 — 마운트 수명·호스트 DOM
import { useEffect, useRef, type MutableRefObject } from "react";
// 역할 — rhwp iframe 편집기
import { createEditor, type RhwpEditor } from "@rhwp/editor";
// 역할 — 동일출처 스튜디오 주소·호스트 높이 대기
import { resolveRhwpStudioUrl, waitForHostSize } from "@/lib/rhwpStudio";

export interface RhwpStudioHostProps {
  // 편집기 인스턴스 — 호스트가 올리고 언마운트에서 destroy 한다
  editorRef: MutableRefObject<RhwpEditor | null>;
  // createEditor 성공 뒤 — 화면이 열기·dirty 를 붙일 때
  onReady?: () => void;
  // 마운트 실패 — AbortError 는 부르지 않는다. 화면이 문구를 정한다
  onError?: (error: unknown) => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 호스트 높이가 생긴 뒤에 createEditor 한다. 화면을 떠나면 abort·destroy 한다
 *   2) 작성·사용양식관리가 그릴 때 실행한다
 *   3) 성공이면 editorRef 에 올리고 onReady. 실패면 onError. 접기는 하지 않는다
 */
export function RhwpStudioHost({
  // 편집기 인스턴스 보관 — 부모가 loadFile·export 에 쓴다
  editorRef,
  // 준비 완료 — 부모가 파일 열기·dirty 를 붙인다
  onReady,
  // 마운트 실패 문구 — 부모가 상태 줄에 쓴다
  onError,
}: RhwpStudioHostProps) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  // 콜백은 최신값을 본다 — createEditor 효과를 다시 돌리지 않으려고 ref 에 둔다
  const onReadyRef = useRef(onReady);
  onReadyRef.current = onReady;
  const onErrorRef = useRef(onError);
  onErrorRef.current = onError;

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return undefined;
    let disposed = false;
    const abort = new AbortController();

    void (async () => {
      try {
        await waitForHostSize(host, abort.signal);
        if (disposed) return;
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
        editorRef.current = created;
        onReadyRef.current?.();
      } catch (error) {
        if (disposed) return;
        // 언마운트로 끊긴 대기는 오류가 아니다 — 문구를 바꾸지 않는다
        if (error instanceof DOMException && error.name === "AbortError") return;
        onErrorRef.current?.(error);
      }
    })();

    return () => {
      disposed = true;
      abort.abort();
      editorRef.current?.destroy();
      editorRef.current = null;
    };
  }, [editorRef]);

  return (
    <div
      // rhwp iframe 호스트 — 남은 높이 전부. overflow-hidden 은 부모 스크롤이 CanvasView page 0 을 깨지 않게 한다
      ref={hostRef}
      className="min-h-0 flex-1 overflow-hidden"
    />
  );
}
