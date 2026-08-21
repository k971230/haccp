/**
 * EduLogHwpPage — HWP 문서 작성 leaf. 공용 에디터에 양식을 고정한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) URL /docs/admin/edu-log-hwp 폴더와 1:1 이다
 *   2) 셸 레지스트리가 이 화면만 마운트한다
 *   3) 양식코드 hwp_sys_008 고정. scrnCd·persistId 는 바꾸지 않는다
 */
import HwpDocumentEditorPage from "@/pages/docs/hwp/HwpDocumentEditorPage";

export default function EduLogHwpPage() {
  return <HwpDocumentEditorPage fixedTmplCd="hwp_sys_008" />;
}
