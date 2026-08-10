/**
 * rhwpStudio — rhwp-studio 동일출처 임베드·도구상자 접기·더티 감지 헬퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) CDN(교차출처) iframe은 contentDocument에 접근할 수 없어 스튜디오 내부 접기가 불가하다
 *   2) Vite(/rhwp 프록시)로 동일출처로 띄운 뒤 #icon-toolbar·#style-bar를 첫 페인트 전에 숨긴다
 *   3) CSS로 iframe을 잘라 올리는 클립은 사용하지 않는다
 *
 * PIPELINE[HF84] HWP 문서 편집 연관
 */

/** 도구상자 접기용 head 스타일 id — 중복 주입 방지 */
const RHWP_FOLD_STYLE_ID = "haccp-rhwp-fold-toolboxes";

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
 *   1) 보기→도구상자→기본·서식 OFF와 같이 #icon-toolbar·#style-bar를 숨긴다
 *   2) iframe load 직후·ready 전에 호출해 펼침 깜빡임을 막는다
 *   3) 교차출처이거나 DOM이 없으면 false — 호스트는 visibility를 유지한다
 */
export function foldRhwpToolboxes(
  // createEditor가 만든 iframe — 동일출처일 때만 contentDocument 접근 가능
  iframe: HTMLIFrameElement | null | undefined,
): boolean {
  // iframe이 없을 때(= 아직 미생성)
  if (!iframe) return false;
  try {
    // 동일출처 스튜디오 문서 — 교차출처면 여기서 SecurityError
    const doc = iframe.contentDocument;
    // doc이 없을 때(= 아직 로드 전·교차출처)
    if (!doc?.head) return false;
    // head 스타일 1회 주입 — 스튜디오 JS가 display를 되돌려도 !important로 유지
    if (!doc.getElementById(RHWP_FOLD_STYLE_ID)) {
      const style = doc.createElement("style");
      style.id = RHWP_FOLD_STYLE_ID;
      style.textContent = "#icon-toolbar,#style-bar{display:none!important}";
      doc.head.appendChild(style);
    }
    // 아이콘 도구상자 — 보기→도구상자→기본
    const iconTb = doc.getElementById("icon-toolbar");
    // iconTb가 있을 때(= 스튜디오 DOM 준비)
    if (iconTb) iconTb.style.display = "none";
    // 서식 도구상자 — 보기→도구상자→서식
    const styleBar = doc.getElementById("style-bar");
    // styleBar가 있을 때(= 스튜디오 DOM 준비)
    if (styleBar) styleBar.style.display = "none";
    // 메뉴 체크 표시 제거 — 스튜디오 토글 active와 맞춤
    doc.querySelectorAll('[data-cmd="view:toolbox-basic"],[data-cmd="view:toolbox-format"]').forEach((el) => {
      el.classList.remove("active");
    });
    return true;
  } catch {
    // 교차출처·접근 거부 — 호스트에서 강제하지 않음
    return false;
  }
}

/** @deprecated foldRhwpToolboxes 사용 — 하위 호환 별칭 */
export const foldRhwpIconToolbox = foldRhwpToolboxes;

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) createEditor 전에 host를 감시해 iframe load 직후 도구상자를 접고 보이게 한다
 *   2) 접기 전까지 iframe visibility:hidden — 펼침 깜빡임 차단
 *   3) 반환 dispose로 Observer·리스너를 제거한다
 */
export function installRhwpEarlyFold(
  // createEditor가 iframe을 append할 호스트 div
  host: HTMLElement,
): () => void {
  // 이미 붙은 iframe에도 훅을 건다
  const hookIframe = (iframe: HTMLIFrameElement) => {
    // 이미 훅된 iframe일 때(= 중복 load 리스너 방지)
    if (iframe.dataset.haccpRhwpFold === "1") return;
    iframe.dataset.haccpRhwpFold = "1";
    // 첫 페인트 전 숨김 — 접기 성공 후 visible
    iframe.style.visibility = "hidden";
    const reveal = () => {
      foldRhwpToolboxes(iframe);
      iframe.style.visibility = "visible";
    };
    // 이미 로드된 iframe일 때(= about:blank 이후 src 교체 전·후)
    if (iframe.contentDocument?.readyState === "complete" && iframe.contentDocument.getElementById("icon-toolbar")) {
      reveal();
    }
    iframe.addEventListener("load", reveal);
  };

  // host 직하위에 이미 iframe이 있을 때
  host.querySelectorAll("iframe").forEach((el) => hookIframe(el as HTMLIFrameElement));

  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      mutation.addedNodes.forEach((node) => {
        // iframe 노드가 추가됐을 때
        if (node instanceof HTMLIFrameElement) hookIframe(node);
        // 컨테이너 안에 iframe이 있을 때
        if (node instanceof HTMLElement) {
          node.querySelectorAll("iframe").forEach((el) => hookIframe(el as HTMLIFrameElement));
        }
      });
    }
  });
  observer.observe(host, { childList: true, subtree: true });

  return () => {
    observer.disconnect();
  };
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
