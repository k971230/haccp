/**
 * DocReasonBox — 반려·결재취소 사유 읽기 전용 칸.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 결재자가 남긴 사유를 비고와 같은 textarea 로 보여 준다
 *   2) 결재첨부·문서함·결재대기·결재완료가 같이 쓴다
 *   3) 읽기 전용이다. 줄마다 한 건, 최신이 맨 위 — SP 가 쌓는다
 *
 * PIPELINE[HF185] 결재 첨부 화면
 * PIPELINE[HF83] 문서함 화면
 */

/** 사유 글자 상한 — tbl_document.reject_reason / cancel_reason varchar(500) */
export const DOC_REASON_MAX = 500;

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 반려·취소 사유를 읽기 전용 textarea 로 보여 준다
 *   2) 값이 있는 반려 사유·결재 취소 사유 칸이 호출한다
 *   3) 작성자는 고치지 못한다
 */
export function DocReasonBox({
  // SP 가 쌓은 사유 본문
  value,
}: {
  value: string;
}) {
  return (
    <>
      <textarea
        // 결재자가 남긴 사유 모음 — 이 화면에서는 고치지 못한다
        value={value}
        readOnly
        disabled
        rows={3}
        className="mt-2 w-full rounded border border-slate-300 px-2 py-1.5 text-sm disabled:bg-slate-50 disabled:text-slate-400"
      />
      <div className="mt-2 flex items-center justify-end gap-3">
        <span className="text-xs text-slate-400">
          {value.length} / {DOC_REASON_MAX}자
        </span>
      </div>
    </>
  );
}
