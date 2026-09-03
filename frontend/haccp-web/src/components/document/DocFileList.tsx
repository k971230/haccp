/**
 * DocFileList — 문서 원본·첨부 카드 목록.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 파일 한 줄을 뱃지·이름·다운로드(·삭제) 카드로 그린다
 *   2) 결재첨부·문서함·결재대기·결재완료가 같은 마크업을 쓴다
 *   3) 원본/첨부를 나누는 분류(splitFiles)도 여기 둔다 — 화면마다 규칙을 다시 쓰지 않는다
 *
 * PIPELINE[HF185] 결재 첨부 화면
 * PIPELINE[HF83] 문서함 화면
 */
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 문서 파일 행
import type { DocumentFileRow } from "@/api/documentApi";

/** 사용자 첨부로 세는 파일 종류 — 본문·완료본 제외 */
export const USER_FILE_KINDS = ["ATTACH", "PHOTO"] as const;

/** 파일 카드 뱃지 — 확장자 대신 짧은 종류 글자 */
export type FileKindBadge = {
  label: string;
  className: string;
};

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 원본(최신 HWP_SRC 1건 + PDF)과 사용자 첨부를 나눈다
 *   2) 결재첨부·문서함 우측 두 섹션이 호출한다
 *   3) HWP_SRC 가 여러 번 쌓여 있어도 원본 칸에는 마지막 한 건만 둔다
 */
export function splitFiles<T extends { fileKind: string; idx?: number }>(
  // 문서 파일 전체
  files: T[],
): { originals: T[]; attachments: T[] } {
  const attachments = files.filter((f) =>
    (USER_FILE_KINDS as readonly string[]).includes(f.fileKind),
  );
  const hwpSrc = files.filter((f) => f.fileKind === "HWP_SRC");
  const latestHwp = hwpSrc.length === 0
    ? []
    : [hwpSrc.reduce((a, b) => ((a.idx ?? 0) >= (b.idx ?? 0) ? a : b))];
  const pdfs = files.filter((f) => f.fileKind === "PDF");
  return { originals: [...latestHwp, ...pdfs], attachments };
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 파일 종류·확장자로 카드 뱃지 글자를 고른다
 *   2) 원본·첨부 카드가 호출한다
 *   3) HWP 본문은 HWP, 완료본은 PDF, 사진은 IMG, 그 밖은 FILE
 */
export function fileKindBadgeOf(
  // 파일 종류
  fileKind: string,
  // 원본 파일명 — 확장자 보조
  fileNm?: string | null,
): FileKindBadge {
  const nm = (fileNm ?? "").toLowerCase();
  if (fileKind === "HWP_SRC" || nm.endsWith(".hwpx") || nm.endsWith(".hwp")) {
    return { label: "HWP", className: "bg-blue-600 text-white" };
  }
  if (fileKind === "PDF" || nm.endsWith(".pdf")) {
    return { label: "PDF", className: "bg-red-600 text-white" };
  }
  if (fileKind === "PHOTO" || /\.(png|jpe?g|gif|webp|bmp)$/.test(nm)) {
    return { label: "IMG", className: "bg-emerald-600 text-white" };
  }
  return { label: "FILE", className: "bg-slate-500 text-white" };
}

/** byte → 사람이 읽는 크기 */
export function fileSizeLabel(size?: number | null): string {
  if (size == null) return "";
  return ` ${(size / 1024).toFixed(1)} KB`;
}

interface DocFileListProps {
  // 이 섹션에 그릴 파일
  files: DocumentFileRow[];
  // 다운로드 — 인증 API 로 Blob 을 받는다
  onDownload: (fileIdx: number, fileNm: string) => void;
  // 삭제 — 있으면 삭제 버튼을 낸다. 원본 칸에는 안 넘긴다
  onDelete?: (fileIdx: number, fileNm: string) => void;
  // 삭제 진행 중 — 버튼을 잠근다
  deleteBusy?: boolean;
  // 빈 목록 안내
  emptyHint?: string;
  // 첨부 목록 pref 키 — 결재첨부만
  persistId?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 파일 카드를 뱃지·이름·다운로드(·삭제)로 그린다
 *   2) 원본·첨부 섹션이 호출한다. 빈 목록은 emptyHint
 *   3) 다운로드 버튼은 variant=download. ghost 를 쓰지 않는다
 */
export function DocFileList({
  files,
  onDownload,
  onDelete,
  deleteBusy,
  emptyHint,
  persistId,
}: DocFileListProps) {
  if (files.length === 0) {
    return emptyHint ? (
      <p className="mt-2 text-xs text-slate-400">{emptyHint}</p>
    ) : null;
  }
  return (
    <ul className="mt-2 space-y-1.5" data-persist-id={persistId}>
      {files.map((file) => {
        const badge = fileKindBadgeOf(file.fileKind, file.fileNm);
        return (
          <li
            key={file.idx}
            className="flex items-center justify-between gap-2 rounded border border-slate-100 bg-slate-50 px-2 py-2 text-xs"
          >
            <span className="flex min-w-0 items-center gap-2">
              <span className={`inline-flex w-10 shrink-0 justify-center rounded py-0.5 text-[10px] font-bold ${badge.className}`}>
                {badge.label}
              </span>
              <span className="min-w-0 truncate">
                {file.fileNm}
                <span className="text-slate-400">{fileSizeLabel(file.fileSize)}</span>
              </span>
            </span>
            <span className="flex items-center gap-1">
              <MesButton
                // 인증 다운로드 — 물리 경로는 API 가 주지 않는다
                variant="download"
                size="sm"
                icon="download"
                onClick={() => onDownload(file.idx, file.fileNm)}
              >
                다운로드
              </MesButton>
              {onDelete ? (
                <MesButton
                  // 사용자 첨부만 지운다. 원본(HWP_SRC·PDF)은 onDelete 를 안 넘긴다
                  variant="danger"
                  size="sm"
                  icon="trash"
                  disabled={deleteBusy}
                  onClick={() => onDelete(file.idx, file.fileNm)}
                >
                  삭제
                </MesButton>
              ) : null}
            </span>
          </li>
        );
      })}
    </ul>
  );
}
