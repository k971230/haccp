/**
 * rhwpStudio — rhwp-studio 동일출처 임베드·더티 감지 헬퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) CDN(교차출처) iframe은 contentDocument에 접근할 수 없어 dirty 감지가 불가하다
 *   2) Vite(/rhwp 프록시)로 동일출처로 띄운다. 마운트는 RhwpStudioHost 가 한다
 *   3) 도구상자는 접지 않는다 — 작성·사용양식관리가 같은 호스트를 쓴다
 *
 * PIPELINE[HF84] HWP 문서 편집 연관
 */

/**
 * 개발자: 박승우
 * 일자: 2026-09-02
 * 코멘트:
 *   1) 호스트 높이가 0인 채로 createEditor 를 부르면 rhwp CanvasView 가
 *      빈 페이지를 그리며 「[CanvasView] 페이지 0 정보가 없습니다」를 콘솔에 남긴다
 *   2) RhwpStudioHost 가 createEditor 직전에 이걸 한 번 기다린다 —
 *      작성·결재·사용양식관리가 같은 호스트 조건을 갖는다.
 *   3) 높이가 생기면 resolve. 언마운트면 abort 로 끊는다
 */
export function waitForHostSize(
  // rhwp iframe 을 붙일 호스트
  host: HTMLElement,
  // 언마운트 abort — 대기 중 화면을 떠나면 관찰을 끊는다
  signal: AbortSignal,
): Promise<void> {
  if (host.clientHeight > 0) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const finish = () => {
      ro.disconnect();
      signal.removeEventListener("abort", onAbort);
    };
    const onAbort = () => {
      finish();
      reject(new DOMException("Aborted", "AbortError"));
    };
    const ro = new ResizeObserver(() => {
      if (host.clientHeight > 0) {
        finish();
        resolve();
      }
    });
    if (signal.aborted) {
      onAbort();
      return;
    }
    signal.addEventListener("abort", onAbort);
    ro.observe(host);
    if (host.clientHeight > 0) {
      finish();
      resolve();
    }
  });
}

/**
 * rhwp-studio URL — 기본은 동일출처 `/rhwp/` (vite·nginx 프록시 필수).
 * VITE_RHWP_STUDIO_URL이 있으면 그 값을 쓴다.
 */
export function resolveRhwpStudioUrl(): string {
  // .env 오버라이드 — 셀프호스팅·스테이징 스튜디오 주소
  const fromEnv = import.meta.env.VITE_RHWP_STUDIO_URL?.trim();
  // fromEnv가 있을 때(= 운영이 별도 스튜디오를 지정)
  if (fromEnv) return fromEnv.endsWith("/") ? fromEnv : `${fromEnv}/`;
  // 기본: 앱과 같은 origin의 /rhwp/ — 교차출처 CDN 대신 프록시 경로
  return `${window.location.origin}/rhwp/`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 동일출처 iframe 문서에 keydown/paste/drop capture 리스너를 붙여 편집 더티를 알린다
 *   2) 행 이동 가드·작성중 뱃지에 쓴다 — SDK에 dirty API가 없어 DOM으로 감지한다
 *   3) 반환 dispose로 리스너를 제거한다
 */
export function installRhwpDirtyListeners(
  // createEditor가 만든 iframe
  iframe: HTMLIFrameElement | null | undefined,
  // dirty로 바꿀 때 호출 — 호스트 setEditorDirty(true)
  onDirty: () => void,
): () => void {
  // iframe이 없을 때
  if (!iframe) return () => undefined;
  try {
    const doc = iframe.contentDocument;
    // doc이 없을 때(= 교차출처)
    if (!doc) return () => undefined;
    const mark = () => onDirty();
    doc.addEventListener("keydown", mark, true);
    doc.addEventListener("paste", mark, true);
    doc.addEventListener("drop", mark, true);
    doc.addEventListener("beforeinput", mark, true);
    return () => {
      doc.removeEventListener("keydown", mark, true);
      doc.removeEventListener("paste", mark, true);
      doc.removeEventListener("drop", mark, true);
      doc.removeEventListener("beforeinput", mark, true);
    };
  } catch {
    return () => undefined;
  }
}
