/**
 * HwpDocumentPreview — 한글 문서형(HWP)의 결재 미리보기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 작성 화면과 같은 rhwp 패널(HwpEditorPane)로 본문 HWP_SRC 를 연다 — 새 뷰어를 만들지 않는다
 *   2) sign-ready·sign-ok 에서 ApprovalDocumentPreview 를 통해 마운트된다
 *   3) 결재 화면에는 저장 경로가 없다. 편집기 참조는 이 컴포넌트가 들고 언마운트에서 정리된다
 *
 * 파일 URL 을 프론트에 노출하지 않는다 — 첨부 idx 로 인증된 다운로드 API 를 그대로 탄다.
 *
 * PIPELINE[HF184] 결재 문서 미리보기
 * PIPELINE[HF182] 연관 모듈
 */
// 역할 — 편집기 인스턴스 참조 (패널이 여기에 올리고 언마운트에서 지운다)
import { useRef } from "react";
import type { RhwpEditor } from "@rhwp/editor";
// 역할 — 작성 화면과 공유하는 rhwp 패널
import { HwpEditorPane } from "@/pages/draft/hwp-doc/HwpEditorPane";
// 역할 — 첨부 계약 (문서 상세 files 와 같은 모양)
import type { HtmlFormDraftFile } from "@/api/draft/htmlFormDraftTypes";

export interface HwpDocumentPreviewProps {
  // 문서 대리키 — tbl_document.idx
  docIdx: number;
  // 양식코드 — 본문이 아직 없을 때 양식 원본을 여는 데 쓴다
  tmplCd: string;
  // 문서 첨부 목록 — 이 중 최신 HWP_SRC 가 본문이다
  files: HtmlFormDraftFile[];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 결재 대상 HWP 본문을 읽기 전용으로 연다
 *   2) 결재 대기·결재 완료 화면에서 문서를 고를 때 마운트된다
 *   3) canEdit=false 라 본문 dirty 를 위로 올리지 않는다 — 저장 버튼 자체가 없다
 */
export function HwpDocumentPreview({ docIdx, tmplCd, files }: HwpDocumentPreviewProps) {
  const editorRef = useRef<RhwpEditor | null>(null);
  return (
    <HwpEditorPane
      // 편집기 인스턴스 보관 — 패널이 언마운트에서 destroy 한다
      editorRef={editorRef}
      tmplCd={tmplCd}
      docIdx={docIdx}
      // 결재 화면은 저장 경로가 없다
      canEdit={false}
      // 읽기 전용 안내 문구
      readOnly
      files={files}
    />
  );
}
