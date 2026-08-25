/**
 * HwpDraftPage — HWP 양식 작성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 공통 HtmlFormDraftPage 에 rhwp 편집기·오늘 할일 팝업·본문 업로드만 얹는다.
 *      검색·목록·행 추가·저장·전송·삭제·전송취소는 HTML 작성 5화면과 같은 코드가 처리한다
 *   2) 우측이 지면(Paper)이 아니라 rhwp 라서 renderDetail 로 그린다 — 그 자리만 다르고 나머지는 형제 화면과 같다
 *   3) 본문은 문서 첨부(HWP_SRC)로 오간다. 저장하면 rhwp 에서 뽑아 올리고, 열면 내려받아 연다
 *
 * 양식 파일·PDF 변환은 기존 HWP 편집 화면과 같은 API 를 쓴다. 새 경로를 만들지 않는다.
 *
 * PIPELINE[HF182] HWP 작성 화면
 */
// 역할 — 팝업 약속·편집기 참조
import { useCallback, useRef, useState } from "react";
// 역할 — rhwp 편집기 타입
import type { RhwpEditor } from "@rhwp/editor";
// 역할 — 본문 업로드
import { uploadDocumentFile } from "@/api/documentApi";
// 역할 — 작성 API·오늘 할일 조회
import { hwpDraftApi, listHwpDraftTasks, type HwpDraftTask } from "@/api/draft/hwpDraftApi";
// 역할 — 양식 작성 공통 화면
import { HtmlFormDraftPage, type HtmlFormDraftPick } from "../HtmlFormDraftPage";
// 역할 — 오늘 할일 선택 팝업
import { HwpTaskLookupModal } from "../HwpTaskLookupModal";
// 역할 — 우측 rhwp 편집기 패널
import { HwpEditorPane } from "./HwpEditorPane";
// 역할 — 업무 오류·안내
import { mesError } from "@/shell/errors";
import { mesToast } from "@/shell/dialog";
// 역할 — 이 화면 상수
import {
  HWP_SRC_KIND,
  PAPER_SUBTITLE,
  PAPER_TITLE,
  PERSIST_ID,
  SCRN_CD,
  SPLIT_KEY,
} from "./HwpDraftRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 저장 파일명을 {YYYY-MM-DD}_{양식명}_{연번} 으로 만든다
 *   2) 본문을 올리기 직전에 부른다
 *   3) 연번은 001 로 보낸다 — 같은 이름이 있으면 서버가 올려 준다
 */
function hwpFileName(
  // baseKey: 일자 YYYYMMDD
  baseKey: string,
  // tmplNm: 양식명
  tmplNm: string,
  // ext: 확장자 (.hwpx)
  ext: string,
): string {
  const date = baseKey.length === 8
    ? `${baseKey.slice(0, 4)}-${baseKey.slice(4, 6)}-${baseKey.slice(6, 8)}`
    : baseKey;
  const safe = (tmplNm || "문서").replace(/[^0-9A-Za-z가-힣._() -]/g, "_").trim();
  return `${date}_${safe}_001${ext}`;
}

export function HwpDraftPage() {
  // 편집기 인스턴스 — 패널이 만들고 저장이 쓴다
  const editorRef = useRef<RhwpEditor | null>(null);
  // 저장 때 쓸 파일명 재료 — 패널을 그릴 때마다 갱신한다
  const nameRef = useRef<{ baseKey: string; tmplNm: string }>({ baseKey: "", tmplNm: "" });
  // 오늘 할일 팝업 — 행 추가가 열고, 고르거나 취소하면 약속을 이행한다
  const [tasks, setTasks] = useState<HwpDraftTask[] | null>(null);
  const pickResolveRef = useRef<((pick: HtmlFormDraftPick | null) => void) | null>(null);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 저장이 끝나면 편집기 내용을 본문 파일로 올린다
   *   2) 공통 화면이 좌측·우측 저장 뒤에 호출한다
   *   3) 편집기가 아직 없으면 아무것도 올리지 않는다 — 좌측 저장만 한 경우다
   */
  const uploadBody = useCallback(async (
    // docIdx: 방금 저장된 문서 idx
    docIdx: number,
  ) => {
    const editor = editorRef.current;
    if (!editor) return;
    const bytes = await editor.exportHwpx();
    const { baseKey, tmplNm } = nameRef.current;
    const fileNm = hwpFileName(baseKey, tmplNm, ".hwpx");
    await uploadDocumentFile(docIdx, HWP_SRC_KIND, new File([Uint8Array.from(bytes)], fileNm, {
      type: "application/vnd.hancom.hwpx",
    }));
    try {
      await editor.notifySaved(fileNm);
    } catch {
      // 저장 통지는 편집기 표시용이라 실패해도 업무를 막지 않는다
    }
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 행 추가 직전에 오늘 할일 팝업을 띄우고 고른 값을 돌려준다
   *   2) 공통 화면의 행 추가가 호출한다
   *   3) 할일이 없으면 팝업 없이 바로 null — 빈 팝업을 닫는 수고를 없앤다
   */
  const pickBeforeAdd = useCallback(async (): Promise<HtmlFormDraftPick | null> => {
    let list: HwpDraftTask[] = [];
    try {
      list = await listHwpDraftTasks();
    } catch (error) {
      mesError(error);
      return null;
    }
    if (list.length === 0) {
      mesToast("오늘 처리할 HWP 문서주기가 없습니다. 양식을 직접 고르세요.", "info");
      return null;
    }
    setTasks(list);
    return new Promise<HtmlFormDraftPick | null>((resolve) => {
      pickResolveRef.current = resolve;
    });
  }, []);

  /** 팝업 응답 — 고르거나 취소하면 행 추가가 이어진다 */
  const answerPick = useCallback((pick: HtmlFormDraftPick | null) => {
    setTasks(null);
    pickResolveRef.current?.(pick);
    pickResolveRef.current = null;
  }, []);

  return (
    <>
      <HtmlFormDraftPage
        // 화면코드 — tbl_screen.scrn_cd. 권한·그리드 pref·API 베이스 기준
        scrnCd={SCRN_CD}
        // 열 너비 저장 키
        persistId={PERSIST_ID}
        // 좌우 분할 비율 저장 키
        splitKey={SPLIT_KEY}
        // 지면 제목 — 양식명이 없을 때만 쓴다
        paperTitle={PAPER_TITLE}
        // 지면 부제
        paperSubtitle={PAPER_SUBTITLE}
        // 작성 API — /api/v1/draft/hwp-doc/hwp-write
        api={hwpDraftApi}
        // 행 추가 전 오늘 할일 팝업 — 취소하면 양식 선택 팝업으로 이어진다
        pickBeforeAdd={pickBeforeAdd}
        // 저장 뒤 본문 업로드 — 이 화면만 파일이 따로 있다
        afterSave={uploadBody}
        // 우측 — 지면 대신 rhwp 편집기. 여는 일은 패널의 useEffect 가 한다
        renderDetail={({ buf, docIdx, canEdit, files }) => {
          nameRef.current = { baseKey: buf?.baseKey ?? "", tmplNm: buf?.tmplNm ?? "" };
          return (
            <HwpEditorPane
              editorRef={editorRef}
              tmplCd={buf?.tmplCd ?? ""}
              docIdx={docIdx}
              canEdit={canEdit}
              files={files}
            />
          );
        }}
      />
      {tasks ? (
        <HwpTaskLookupModal
          scrnCd={SCRN_CD}
          tasks={tasks}
          // 고른 할일의 양식·기준일로 행을 채운다
          onSelect={(task) => answerPick({
            tmplCd: task.tmplCd,
            tmplNm: task.tmplNm,
            baseDt: task.baseDt,
            docIdx: task.docIdx ?? null,
          })}
          // 취소 — 빈 행만 추가하고 양식 선택 팝업으로 넘어간다
          onSkip={() => answerPick(null)}
        />
      ) : null}
    </>
  );
}
