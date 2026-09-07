/**
 * DocumentPrintLayer — 선택한 HTML 문서를 A4 지면으로 쌓아 브라우저 인쇄한다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 작성 화면과 같은 Paper 를 variant=a4 로 그린다. HTML 문자열·iframe 을 만들지 않는다
 *   2) createPortal 로 #doc-print-root 에 쌓고, 화면에는 안 보이게 CSS 로 숨긴다
 *   3) 매핑 없는 구양식은 건너뛴다. 전부 적재되면 window.print() 한 번이다
 *
 * PIPELINE[HF187] HTML A4 일괄 인쇄
 * PIPELINE[HF184, HF172] 연관 — 미리보기 레지스트리·지면 변환
 */
// 역할 — 적재 수명·인쇄 1회 가드
import { useEffect, useRef, useState } from "react";
// 역할 — body 아래 인쇄 전용 루트
import { createPortal } from "react-dom";
// 역할 — 상세 → 지면 버퍼 · 지면 표시 props
import {
  detailToDraftBuf,
  draftPaperViewProps,
  type HtmlFormDraftBuf,
} from "@/pages/draft/htmlFormDraftShared";
// 역할 — 양식코드 → 지면·API
import { previewEntryOf, type DocumentPreviewEntry } from "./documentPreviewRegistry";
// 역할 — 인쇄 대화상자 상한. axios 타임아웃과 다르다
import { PRINT_DIALOG_WAIT_MS } from "./printWaitMs";

/** 인쇄할 HTML 문서 1건 — 목록에서 체크한 행 */
export interface HtmlPrintJob {
  // 문서 대리키 — tbl_document.idx
  docIdx: number;
  // 양식코드 — 지면·API 를 고르는 키
  tmplCd: string;
  // 양식명 — 지면 제목. 없으면 Rule 기본 제목
  tmplNm?: string | null;
}

interface DocumentPrintLayerProps {
  // 인쇄할 HTML 문서 — 빈 배열이면 인쇄하지 않고 바로 끝낸다
  jobs: HtmlPrintJob[];
  // 인쇄 대화상자가 닫히거나 찍을 지면이 없을 때. skipped 는 매핑 없는 구양식·조회 실패 건수
  onDone: (skipped: number) => void;
}

interface LoadedPage {
  job: HtmlPrintJob;
  buf: HtmlFormDraftBuf;
  entry: DocumentPreviewEntry;
}

/** 인쇄 루트 — 없으면 body 에 만든다. 화면용 CSS 가 display:none 이다 */
function printRootOf(): HTMLElement {
  let el = document.getElementById("doc-print-root");
  if (!el) {
    el = document.createElement("div");
    el.id = "doc-print-root";
    document.body.appendChild(el);
  }
  return el;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 선택 HTML 문서를 받아 A4 Paper 를 인쇄 레이어에 쌓는다
 *   2) 문서함 인쇄 명령이 HTML 건이 있을 때만 마운트한다
 *   3) body.doc-printing 을 켜서 미리보기 지면이 같이 나가지 않게 한다
 */
export function DocumentPrintLayer({
  // 체크한 HTML 문서
  jobs,
  // 인쇄 종료 — HWP 순차 인쇄로 이어 간다
  onDone,
}: DocumentPrintLayerProps) {
  const [pages, setPages] = useState<LoadedPage[] | null>(null);
  const [skipped, setSkipped] = useState(0);
  const printedRef = useRef(false);
  const onDoneRef = useRef(onDone);
  onDoneRef.current = onDone;

  useEffect(() => {
    let alive = true;
    void (async () => {
      let skip = 0;
      const loaded: LoadedPage[] = [];
      for (const job of jobs) {
        const entry = previewEntryOf(job.tmplCd);
        // 매핑이 없을 때(= 구양식·예시) 인쇄 대상에서 뺀다
        if (!entry) {
          skip += 1;
          continue;
        }
        try {
          const detail = await entry.api.detail(job.tmplCd, job.docIdx);
          if (!alive) return;
          loaded.push({
            job,
            entry,
            buf: detailToDraftBuf(detail, { tmplCd: job.tmplCd, tmplNm: job.tmplNm ?? "" }),
          });
        } catch {
          skip += 1;
        }
      }
      if (!alive) return;
      setSkipped(skip);
      setPages(loaded);
    })();
    return () => {
      alive = false;
    };
  }, [jobs]);

  useEffect(() => {
    if (pages == null) return undefined;
    if (printedRef.current) return undefined;
    printedRef.current = true;
    if (pages.length === 0) {
      const empty = window.setTimeout(() => onDoneRef.current(skipped), 0);
      return () => window.clearTimeout(empty);
    }
    document.body.classList.add("doc-printing");
    const finish = () => {
      window.removeEventListener("afterprint", finish);
      document.body.classList.remove("doc-printing");
      onDoneRef.current(skipped);
    };
    window.addEventListener("afterprint", finish);
    const start = window.setTimeout(() => {
      window.print();
    }, 80);
    const fallback = window.setTimeout(finish, PRINT_DIALOG_WAIT_MS);
    return () => {
      window.clearTimeout(start);
      window.clearTimeout(fallback);
      window.removeEventListener("afterprint", finish);
      document.body.classList.remove("doc-printing");
    };
  }, [pages, skipped]);

  if (pages == null || pages.length === 0) return null;

  return createPortal(
    <>
      {pages.map(({ job, buf, entry }) => {
        const { Paper } = entry;
        return (
          <div
            // 문서 사이 페이지 나눔 — CSS break-after
            key={job.docIdx}
            className="doc-print-page"
          >
            <Paper
              // 실제 작성 데이터 지면
              mode="write"
              // A4 폭 — 인쇄 정본
              variant="a4"
              // 인쇄 지면은 고칠 수 없다
              locked
              editable={false}
              {...draftPaperViewProps(buf, {
                paperTitle: entry.paperTitle,
                paperSubtitle: entry.paperSubtitle,
              })}
            />
          </div>
        );
      })}
    </>,
    printRootOf(),
  );
}
