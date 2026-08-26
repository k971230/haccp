/**
 * ApprovalDocumentPreview — 결재 화면 공통 문서 본문 미리보기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 결재 화면은 문서 종류(HWP/HTML)를 몰라도 된다 — 이 컴포넌트가 docKind 로 렌더러를 고른다
 *   2) sign-ready(결재 대기)·sign-ok(결재 완료)가 같은 컴포넌트를 쓴다. 화면마다 복제하지 않는다
 *   3) 두 경로 모두 읽기전용이다. 결재자는 확인 후 결재·반려·취소만 한다
 *
 * 첨부파일 미리보기와는 다른 개념이다 — 여기는 문서 본문, 첨부는 목록·다운로드로만 다룬다.
 * 무거운 rhwp 편집기는 문서를 고른 뒤에만 마운트된다 (목록 전체를 미리 그리지 않는다).
 *
 * PIPELINE[HF184] 결재 문서 미리보기
 * PIPELINE[HF82, HF103] 연관 모듈
 */
// 역할 — 양식 유형(HWP/HTML) 판별
import { isHwpKind } from "@/lib/docKind";
// 역할 — 첨부 계약 (문서 상세 files 와 같은 모양)
import type { HtmlFormDraftFile } from "@/api/draft/htmlFormDraftTypes";
// 역할 — 종류별 렌더러
import { HtmlDocumentPreview } from "./HtmlDocumentPreview";
import { HwpDocumentPreview } from "./HwpDocumentPreview";

export interface ApprovalDocumentPreviewProps {
  // 문서 대리키 — tbl_document.idx
  docIdx: number;
  // 양식코드 — HTML 은 지면·API 를, HWP 는 원본 양식을 고르는 키
  tmplCd: string;
  // 양식명 — 지면 제목
  tmplNm?: string | null;
  // 문서 유형 — hwp:rhwp 문서형, html:DB 입력형
  docKind?: string | null;
  // 문서 첨부 목록 — HWP 본문(HWP_SRC)을 여기서 찾는다
  files: HtmlFormDraftFile[];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 결재 대상 문서 본문을 읽기전용으로 그린다
 *   2) 결재 화면 우측 상세에서 선택 문서 1건에 대해 호출한다
 *   3) 문서를 고르지 않았으면 아무것도 그리지 않는다
 */
export function ApprovalDocumentPreview({
  docIdx,
  tmplCd,
  tmplNm,
  docKind,
  files,
}: ApprovalDocumentPreviewProps) {
  // 문서가 없을 때(= 목록에서 아직 고르지 않음) 렌더러를 만들지 않는다
  if (!docIdx || !tmplCd) return null;
  return isHwpKind(docKind)
    ? <HwpDocumentPreview docIdx={docIdx} tmplCd={tmplCd} files={files} />
    : <HtmlDocumentPreview docIdx={docIdx} tmplCd={tmplCd} tmplNm={tmplNm} />;
}
