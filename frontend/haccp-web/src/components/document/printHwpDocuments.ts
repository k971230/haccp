/**
 * printHwpDocuments — HWP 문서를 서버 PDF 로 바꾼 뒤 건별로 인쇄 대화상자를 연다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) rhwp 뷰어에는 인쇄가 없어서 기존 export-pdf API 를 탄다
 *   2) 문서함은 결재완료(APV) 문서다. 서버가 본문을 안 바꾸고 PDF 완료본만 쓰거나 만든다
 *   3) 브라우저가 PDF 여러 건을 한 인쇄 작업으로 묶지 못해 건별 iframe.print() 다
 *      인쇄 대화상자가 모달이라 한 건이 끝나야 다음 건이 열린다
 *
 * PIPELINE[HF187] HWP PDF 인쇄
 * PIPELINE[HF82] 연관 — 문서 파일 API
 */
// 역할 — PDF 변환·파일 다운로드
import { downloadDocumentFile, exportDocumentPdf } from "@/api/documentApi";

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 숨은 iframe 에 PDF 를 넣고 인쇄 대화상자를 연다
 *   2) HWP 문서 한 건을 인쇄할 때 호출한다
 *   3) afterprint 또는 print() 반환 후 iframe 을 지운다. 실패하면 예외
 */
function printPdfBlob(
  // 서버가 준 PDF 바이너리 — MIME 이 비어도 pdf 로 감싼다
  blob: Blob,
): Promise<void> {
  const pdf = blob.type.includes("pdf") ? blob : new Blob([blob], { type: "application/pdf" });
  const url = URL.createObjectURL(pdf);
  return new Promise<void>((resolve, reject) => {
    const iframe = document.createElement("iframe");
    iframe.setAttribute("aria-hidden", "true");
    iframe.style.position = "fixed";
    iframe.style.right = "0";
    iframe.style.bottom = "0";
    iframe.style.width = "0";
    iframe.style.height = "0";
    iframe.style.border = "0";
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      iframe.remove();
      URL.revokeObjectURL(url);
      resolve();
    };
    iframe.onload = () => {
      const win = iframe.contentWindow;
      if (!win) {
        finish();
        return;
      }
      win.addEventListener("afterprint", finish);
      try {
        win.focus();
        win.print();
      } catch (error) {
        iframe.remove();
        URL.revokeObjectURL(url);
        reject(error);
        return;
      }
      // print() 가 동기 차단이면 afterprint 가 이미 난 뒤다. 아직이면 상한까지 기다린다
      window.setTimeout(finish, 180_000);
    };
    iframe.onerror = () => {
      iframe.remove();
      URL.revokeObjectURL(url);
      reject(new Error("PDF 를 열 수 없습니다."));
    };
    iframe.src = url;
    document.body.appendChild(iframe);
  });
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 선택한 HWP 문서를 순서대로 PDF 변환·인쇄한다
 *   2) 문서함 인쇄 명령이 HTML 일괄 인쇄 다음에 호출한다
 *   3) 한 건이 실패해도 다음 건을 이어 간다. 실패 건수는 반환한다
 */
export async function printHwpDocuments(
  // 인쇄할 HWP 문서 대리키 — 체크한 순서
  docIdxList: number[],
  // 한 건 실패 시 업무 문구를 남기는 콜백. 던지지 않는다
  onItemError?: (error: unknown) => void,
): Promise<{ printed: number; failed: number }> {
  let printed = 0;
  let failed = 0;
  for (const docIdx of docIdxList) {
    try {
      const file = await exportDocumentPdf(docIdx);
      const blob = await downloadDocumentFile(file.idx);
      await printPdfBlob(blob);
      printed += 1;
    } catch (error) {
      failed += 1;
      onItemError?.(error);
    }
  }
  return { printed, failed };
}
