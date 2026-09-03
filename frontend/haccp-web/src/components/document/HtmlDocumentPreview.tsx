/**
 * HtmlDocumentPreview — DB 입력형(HTML) 문서의 결재 미리보기 지면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 결재 당시 저장된 작성 데이터로 기존 지면(Paper)을 읽기전용으로 그린다
 *   2) sign-ready·sign-ok 에서 ApprovalDocumentPreview 를 통해 마운트된다
 *   3) HTML 문자열을 만들어 iframe 에 넣지 않는다 — 작성 화면과 같은 컴포넌트를 그대로 쓴다
 *      승인은 되고 지면만 한 박자 늦던 것은 status 가 바뀌면 다시 읽어서 막는다
 *
 * 지면 값은 양식(template)의 현재 모습이 아니라 문서가 가진 항목 사본이다.
 * 상세 SP 가 tbl_*_item(문서 소유 행)에서 읽으므로 나중에 양식을 고쳐도 상신 당시 지면이 유지된다.
 *
 * PIPELINE[HF184] 결재 문서 미리보기
 * PIPELINE[HF172, HF173] 연관 모듈
 */
// 역할 — 문서 적재 수명·중복 요청 차단
import { useEffect, useState } from "react";
// 역할 — 업무 오류 문구
import { toUserMessage } from "@/shell/errors";
// 역할 — 상세 응답 → 지면 버퍼 · 지면 표시 props (작성 화면과 같은 변환)
import {
  detailToDraftBuf,
  draftPaperViewProps,
  type HtmlFormDraftBuf,
} from "@/pages/draft/htmlFormDraftShared";
// 역할 — 양식코드 → 지면·API 매핑
import { previewEntryOf } from "./documentPreviewRegistry";

export interface HtmlDocumentPreviewProps {
  // 문서 대리키 — tbl_document.idx
  docIdx: number;
  // 양식코드 — 지면·API 를 고르는 키
  tmplCd: string;
  // 양식명 — 지면 제목. 없으면 Rule 기본 제목
  tmplNm?: string | null;
  // 문서 상태 WRK/REQ/APV/RJT — 같은 문서를 승인해 docIdx 가 그대로여도 지면을 다시 읽는다
  status?: string | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 선택 문서 1건의 작성 데이터를 받아 지면을 읽기전용으로 그린다
 *   2) 결재 대기·결재 완료 화면에서 문서를 고를 때마다 다시 적재한다
 *   3) 매핑 없는 구양식은 지면 대신 안내 문구를 보여 준다 — 결재 자체는 막지 않는다
 *      승인 직후 같은 docIdx 면 status(REQ→APV)가 바뀌어 승인자 칸을 다시 채운다
 */
export function HtmlDocumentPreview({ docIdx, tmplCd, tmplNm, status }: HtmlDocumentPreviewProps) {
  const entry = previewEntryOf(tmplCd);
  const [buf, setBuf] = useState<HtmlFormDraftBuf | null>(null);
  const [message, setMessage] = useState("문서를 불러오고 있습니다.");

  useEffect(() => {
    // 매핑이 없을 때(= 구양식·예시) 요청을 보내지 않는다
    if (!entry || !docIdx) return undefined;
    // 응답이 늦게 와서 다른 문서 지면을 덮어쓰지 않게 한다
    let alive = true;
    setBuf(null);
    setMessage("문서를 불러오고 있습니다.");
    void (async () => {
      try {
        const detail = await entry.api.detail(tmplCd, docIdx);
        if (!alive) return;
        // 로그인 사용자를 넘기지 않는다 — 결재자 이름이 작성자 칸에 채워지면 안 된다
        setBuf(detailToDraftBuf(detail, { tmplCd, tmplNm: tmplNm ?? "" }));
      } catch (error) {
        if (alive) setMessage(toUserMessage(error));
      }
    })();
    return () => {
      alive = false;
    };
  }, [docIdx, entry, tmplCd, tmplNm, status]);

  // 매핑이 없을 때(= html_sys_* 구양식) 지면을 그리지 않는다
  if (!entry) {
    return (
      <p className="p-4 text-xs text-slate-500">
        이 양식은 결재 화면에서 지면을 미리 볼 수 없습니다. 「작성화면」으로 열어 확인하세요.
      </p>
    );
  }

  if (!buf) {
    return <p className="p-4 text-xs text-slate-500">{message}</p>;
  }

  const { Paper } = entry;
  return (
    <Paper
      // 실제 작성 데이터 지면 — 기준관리(template)가 아니다
      mode="write"
      // A4 폭 원본 — 화면에서 일정한 크기. 인쇄는 DocumentPrintLayer 가 따로 찍는다
      variant="a4"
      // 결재자는 문서를 고칠 수 없다
      locked
      editable={false}
      // 헤더·점검 행·하단 4열·기록 표 — 작성 화면과 같은 값
      {...draftPaperViewProps(buf, {
        paperTitle: entry.paperTitle,
        paperSubtitle: entry.paperSubtitle,
      })}
    />
  );
}
