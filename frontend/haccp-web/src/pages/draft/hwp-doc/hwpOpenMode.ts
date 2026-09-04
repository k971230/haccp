/**
 * hwpOpenMode — HWP 편집기가 양식 원본을 열지, 작성본을 열지, 기다릴지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 저장된 문서인데 본문 첨부가 아직 없으면 양식 원본을 열지 않는다
 *   2) HwpEditorPane 이 행을 바꿀 때 호출한다
 *   3) wait 인데 원본을 열면 빈 양식이 작성본을 덮는다
 *
 * PIPELINE[HF186] HWP 열기 판정
 */

/** 편집기에 실을 대상 — 작성본 / 양식 원본 / 첨부 대기 */
export type HwpOpenMode = "source" | "template" | "wait";

/**
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 본문 첨부가 있으면 작성본, 저장 전이면 양식 원본, 저장 문서인데 첨부가 없으면 대기
 *   2) HwpEditorPane 로드 효과가 호출한다
 *   3) wait 는 원본 loadFile 금지
 */
export function hwpOpenMode(
  // 저장된 문서 idx. 없으면 신규
  docIdx: number | null | undefined,
  // 첨부 목록에 HWP_SRC 가 있는지
  hasSource: boolean,
): HwpOpenMode {
  if (hasSource) return "source";
  if (docIdx != null && docIdx > 0) return "wait";
  return "template";
}

/** 편집기가 지금 들고 있는 것 — 패널이 알려 주고 저장 가드가 본다 */
export type HwpOpenedRef = {
  // 무엇을 읽어 두었나
  mode: HwpOpenMode;
  // 그때의 문서 idx. template(신규)면 null 이다
  docIdx: number | null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) 지금 편집기 내용을 이 문서의 본문으로 올려도 되는지 정한다
 *   2) HwpDraftPage.uploadBody 가 올리기 직전에 부른다
 *   3) 대조하는 것은 docIdx 가 아니라 mode 다
 *
 * docIdx 단독 대조는 안 된다 — 신규 행은 template 로 열려 편집기가 아는 idx 가 null 인데
 * 저장은 서버가 방금 발급한 새 idx 로 부른다. 그걸로 막으면 **모든 첫 저장**의 본문이 안 올라간다.
 *
 * wait 는 「이 문서는 idx 가 있는데 본문 파일이 없고, 편집기가 이 문서를 위해 아무것도 안 읽었다」다.
 * 그 상태의 편집기 내용은 정의상 남의 것이라 올리면 앞 문서가 이 문서로 저장된다.
 */
export function canUploadBody(
  // 편집기가 들고 있는 것
  opened: HwpOpenedRef,
  // 지금 저장하는 문서 idx
  docIdx: number,
): boolean {
  if (opened.mode === "wait") return false;
  if (opened.mode === "source" && opened.docIdx !== docIdx) return false;
  return true;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) 편집기가 알려 온 상태를 부모가 어떻게 받아들일지 정한다
 *   2) HwpDraftPage 의 onOpened 가 부른다
 *   3) 같은 문서를 다시 읽는 중이면 잠그지 않는다
 *
 * `wait` 가 막으려는 것은 **편집기가 남의 문서를 들고 있는 것**이다.
 * 같은 `docIdx` 를 다시 읽는 중이라면 편집기가 든 것은 여전히 이 문서라 잠글 이유가 없다.
 *
 * 이 자리가 필요한 이유: 본문을 저장하면 `replaceExistingHwpSrc` 가 옛 HWP_SRC 를 지우고
 * **새 idx** 로 다시 넣는다. 저장 직후 `afterAll` 이 상세를 다시 읽어 `files` 를 갈아 끼우면
 * 첨부 idx 가 달라져 편집기가 **자기가 방금 올린 파일을 다시 내려받는다.**
 * 그 동안 `wait` 로 잠그면, 저장을 연달아 누른 사용자가
 * 「이 문서는 편집기에 열려 있지 않습니다」로 거절당한다 — 실제로는 열려 있다.
 *
 * 남는 위험 하나: 같은 문서의 본문을 남이 바꿔 그 새 본문을 내려받는 중에 저장하면
 * 내 화면 내용이 그 위에 덮인다. 문서 하나 안의 덮어쓰기라 이 수정 이전과 같고,
 * 여기서 막으려던 **다른 문서로 새는 것**과는 층이 다르다.
 */
export function nextOpenedRef(
  // 지금 부모가 알고 있는 상태
  current: HwpOpenedRef,
  // 편집기가 알려 온 상태
  mode: HwpOpenMode,
  // 그 상태의 문서 idx
  docIdx: number | null,
): HwpOpenedRef {
  if (mode === "wait" && current.mode === "source" && current.docIdx === docIdx) {
    return current;
  }
  return { mode, docIdx };
}
