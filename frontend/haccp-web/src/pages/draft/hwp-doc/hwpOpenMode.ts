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
