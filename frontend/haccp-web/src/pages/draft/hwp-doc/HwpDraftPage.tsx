/**
 * HwpDraftPage — HWP 양식 작성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 공통 HtmlFormDraftPage 에 rhwp 편집기·오늘 할일 팝업·본문 업로드만 얹는다.
 *      검색·목록·행 추가·저장·전송·삭제·전송취소는 HTML 작성 5화면과 같은 코드가 처리한다
 *   2) 우측이 지면(Paper)이 아니라 rhwp 라서 renderDetail 로 그린다 — 그 자리만 다르고 나머지는 형제 화면과 같다
 *   3) 본문은 문서 첨부(HWP_SRC)로 오간다. 좌측 저장이 첫 파일을 만들고,
 *      이후 칸 저장은 그 파일을 덮어쓴다. dirty 는 목록 _rowState 와 섞지 않는다
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
// 역할 — 편집기가 무엇을 들고 있는지 (저장 가드 기준)
import { canUploadBody, nextOpenedRef, type HwpOpenedRef } from "./hwpOpenMode";
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
  /*
   * 편집기가 지금 무엇을 들고 있는지. 패널이 알려 준다.
   *
   * 초기값이 wait 인 것이 중요하다 — 패널이 준비되기 전(ready·editor·tmplCd 미충족)에는
   * 통지가 아예 없다. template 로 시작하면 그 사이 저장이 **빈 파일**을 올린다.
   */
  const openedRef = useRef<HwpOpenedRef>({ mode: "wait", docIdx: null });
  // 본문 dirty — rhwp 칸 입력. 목록 행 _rowState 와 다른 축이다
  const editorDirtyRef = useRef(false);
  const isBodyDirty = useCallback(() => editorDirtyRef.current, []);
  const clearBodyDirty = useCallback(() => {
    editorDirtyRef.current = false;
  }, []);
  const markBodyDirty = useCallback(() => {
    editorDirtyRef.current = true;
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 저장이 끝나면 편집기 내용을 본문 파일로 올린다 — 첫 저장이면 생성, 이후면 덮어쓰기
   *   2) 공통 화면이 좌측 저장·본문만 dirty 인 우측 저장 뒤에 호출한다
   *   3) 편집기가 **이 문서를 읽어 둔** 경우에만 올린다. 아니면 false 로 알린다
   *
   * 올렸으면 true. 편집기가 이 문서를 안 들고 있어 아무것도 안 올렸으면 false 다.
   * 호출측(runSaveDetail)이 이 값을 그대로 사용자에게 전한다 —
   * 안 올렸는데 「저장했습니다」가 뜨면 사람은 본문이 들어간 줄 안다.
   */
  const uploadBody = useCallback(async (
    // docIdx: 방금 저장된 문서 idx
    docIdx: number,
  ): Promise<boolean> => {
    const editor = editorRef.current;
    if (!editor) return false;
    /*
     * 대조하는 것은 docIdx 가 아니라 mode 다.
     *
     * 신규 행은 hwpOpenMode(null, false) → template 로 열려 편집기가 아는 docIdx 가 null 인데,
     * 저장은 서버가 방금 발급한 새 idx 로 부른다. docIdx 만 대조하면 **모든 첫 저장**이 막힌다.
     *
     * wait 는 「이 문서는 idx 가 있는데 본문 파일이 없고, 편집기가 이 문서를 위해 아무것도 안 읽었다」다.
     * 그 상태의 편집기 내용은 정의상 남의 것이다. source(기존 덮어쓰기)만 idx 를 대조한다.
     */
    if (!canUploadBody(openedRef.current, docIdx)) {
      mesToast("이 문서는 편집기에 열려 있지 않습니다. 문서를 다시 연 뒤 저장하세요.", "warn");
      return false;
    }
    const bytes = await editor.exportHwpx();
    const { baseKey, tmplNm } = nameRef.current;
    const fileNm = hwpFileName(baseKey, tmplNm, ".hwpx");
    await uploadDocumentFile(docIdx, HWP_SRC_KIND, new File([Uint8Array.from(bytes)], fileNm, {
      type: "application/vnd.hancom.hwpx",
    }));
    editorDirtyRef.current = false;
    try {
      await editor.notifySaved(fileNm);
    } catch {
      // 저장 통지는 편집기 표시용이라 실패해도 업무를 막지 않는다
    }
    // 올린 뒤에는 편집기가 이 문서를 들고 있는 것이 확정이다 — 연달아 저장해도 막히지 않게 한다
    openedRef.current = { mode: "source", docIdx };
    return true;
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
        // 본문 dirty 여부 — 목록이 깨끗해도 칸 입력이면 덮어쓰기를 탄다
        // 이탈여부 — 우측이 rhwp 편집기라 지면 하단 시그널을 둘 자리가 없다. 목록 칸으로 켠다
      showDeviationColumn
      isBodyDirty={isBodyDirty}
        // 본문 저장·로드 성공 뒤 dirty 해제
        clearBodyDirty={clearBodyDirty}
        // 우측 — 지면 대신 rhwp 편집기. 여는 일은 패널의 useEffect 가 한다
        renderDetail={({ buf, docIdx, canEdit, files }) => {
          nameRef.current = { baseKey: buf?.baseKey ?? "", tmplNm: buf?.tmplNm ?? "" };
          return (
            <HwpEditorPane
              // 부모가 저장 때 쓰는 편집기 참조
              editorRef={editorRef}
              // 열린 문서의 양식코드 — 비면 양식 원본을 열 수 없다
              tmplCd={buf?.tmplCd ?? ""}
              // 저장된 문서 idx — 없으면 양식 원본을 연다
              docIdx={docIdx}
              // 우측을 고칠 수 있는 상태인지 — 저장 전·전송 이후는 false
              canEdit={canEdit}
              // 문서 첨부 목록 — 최신 HWP_SRC 를 연다
              files={files}
              // 칸 입력 dirty — 목록 행 상태는 건드리지 않는다
              onDirty={markBodyDirty}
              // 파일을 연 뒤 깨끗 — 로드가 본문 변경으로 안 보이게
              onClean={clearBodyDirty}
              // 편집기가 무엇을 들고 있는지 — uploadBody 가 이걸 보고 올릴지 정한다
              // 같은 문서를 다시 읽는 중이면 잠그지 않는다 — 저장 직후 재조회가 그 재로드를 스스로 부른다
              onOpened={(mode, idx) => {
                openedRef.current = nextOpenedRef(openedRef.current, mode, idx);
              }}
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
