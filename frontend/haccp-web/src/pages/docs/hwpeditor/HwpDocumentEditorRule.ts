/**
 * HwpDocumentEditorRule — HWP 작성기 목록 규칙·파일명·서명 평탄화.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) Page는 렌더·상태·API·rhwp만 담당하고 컬럼·잠금·파일명 규칙은 이 파일이 갖는다
 *   2) persistId는 화면코드별로 `hwp-document-list-${scrnCd}` 이다. 값을 바꾸지 않는다
 *   3) 서명 PNG 평탄화는 한글 붙여넣기 검정을 막기 위한 화면 전용 변환이다
 *
 * PIPELINE[HF84] HWP 작성기 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 목록 메타 기본 필드
import type { DocListMeta } from "@/hooks/useDocFormSession";

/** 레거시 단독 화면코드 — leaf는 PageScrnContext의 scrn_cd가 우선 */
export const FALLBACK_SCRN_CD = "hwp-document-editor" as const;

/** 좌측 목록 — 신규행만 기준일 편집 */
export const LIST_GRID_RULES: ScreenGridRules = {
  newOnly: ["baseDtDisp", "baseKey"],
};

/** 좌측 일자 문서 목록 메타 */
export type ListMeta = DocListMeta & {
  baseDtDisp?: string;
  statusNm?: string;
};

/** 건별 세션 버퍼 — 목록 동기용 */
export type Buf = {
  docIdx: number | null;
  baseKey: string;
  tmplCd: string;
};

/** 목록 persistId — 화면코드마다 열 설정을 분리한다 */
export function listPersistIdOf(screenCode: string): string {
  return `hwp-document-list-${screenCode}`;
}

/** byte → 첨부 목록용 텍스트 */
export function fileSize(size?: number | null): string {
  return size == null ? "" : `${(size / 1024).toFixed(1)} KB`;
}

/**
 * 파일명에 쓸 토큰 — 경로·윈도 금지문자·공백을 _ 로 치환한다.
 * 양식명_일자_001.hwpx 의 양식명 부분에 쓴다.
 */
export function sanitizeFileToken(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return "양식";
  return trimmed
    .replace(/[\\/:*?"<>|]/g, "_")
    .replace(/\s+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "")
    || "양식";
}

/**
 * HWP_SRC 표시 파일명 — 양식명_YYYYMMDD_001.hwpx (연번 3자리).
 * 같은 문서 재저장 시 기존 연번을 유지한다.
 */
export function buildHwpSrcFileName(
  tmplNm: string,
  baseDt: string,
  seq: number,
): string {
  const safeSeq = Number.isFinite(seq) && seq > 0 ? Math.floor(seq) : 1;
  return `${sanitizeFileToken(tmplNm)}_${baseDt}_${String(safeSeq).padStart(3, "0")}.hwpx`;
}

/** 기존 HWP_SRC 파일명에서 _001.hwpx 연번을 읽는다 — 없으면 null */
export function parseHwpSrcSeq(fileNm?: string | null): number | null {
  if (!fileNm) return null;
  const m = fileNm.match(/_(\d{3})\.(hwp|hwpx)$/i);
  if (!m) return null;
  const n = Number.parseInt(m[1], 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/**
 * 서명 이미지를 흰 배경에 합성한 PNG로 바꾼다.
 * 서명 원본은 배경이 투명한 RGBA PNG인데, 클립보드를 거쳐 한글로 들어갈 때
 * 알파가 없는 비트맵으로 변환되면서 투명 영역이 검정이 된다.
 * 복사 직전에만 흰색을 깔아 평탄화한다. 서버에 저장된 원본은 투명 그대로 둔다.
 */
export async function flattenSignToWhitePng(blob: Blob): Promise<Blob> {
  const bitmap = await createImageBitmap(blob);
  const canvas = document.createElement("canvas");
  canvas.width = bitmap.width;
  canvas.height = bitmap.height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    bitmap.close();
    return blob;
  }
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(bitmap, 0, 0);
  bitmap.close();
  return await new Promise<Blob>((resolve) =>
    canvas.toBlob((out) => resolve(out ?? blob), "image/png"),
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 좌측 일자 목록 열. 기준일만 신규 편집
 *   2) Page가 useMemo로 호출한다
 *   3) persistId는 listPersistIdOf
 */
export function buildListColumns(): GridColumn<ListMeta>[] {
  return [
    { field: "baseDtDisp", header: "기준일", width: 120, editableOnNew: true, type: "date" },
    { field: "docNo", header: "문서번호", width: 120 },
    { field: "statusNm", header: "상태", width: 80 },
  ];
}
