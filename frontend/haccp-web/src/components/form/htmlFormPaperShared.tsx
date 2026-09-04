/**
 * htmlFormPaperShared — HTML 양식 지면 공통 타입·서명 슬롯.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 헤더·풋터·서명 칸을 공유한다. 본문 표 HTML 은 양식별
 *   2) 공정점검·검증점검은 HygPrcPaper 한 벌. 포장·가열·금속은 헤더·풋터·개선조치만 공유
 *   3) 저장 API 는 호출하지 않는다
 *
 * PIPELINE[HF135] HTML 양식 지면 공통
 */
// 역할 — 서명 Blob URL 수명 · 행추가 슬롯 children
import { useEffect, useState, type ReactNode } from "react";
// 역할 — 항목 패치 · 입력유형별 라디오/값칸 판단
import { htmlFormInputLayout, type HtmlFormItem } from "@/api/docs/htmlFormApi";
// 역할 — 서명 이미지 Blob (signYn=Y 이고 id 있을 때)
import { fetchUserSignBlob } from "@/api/sys/userApi";
// 역할 — 적합/부적합 공통코드
import { JUDGE_PF_MAIN_CD, useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — HTML type=time. 값은 HH:mm
import { DocCellTime } from "./DocCell";

export type HtmlFormPaperMode = "template" | "write";
export type HtmlFormPaperVariant = "a4" | "fill";

export interface HtmlFormHeader {
  // 지면 제목 fallback — 양식명. hdr-title 항목이 있으면 그걸 쓴다.
  // 작성 목록 tbl_document.title(식별용)을 넣지 않는다
  title: string;
  // 제목 아래 부제 — 기본 (매일 작성)
  subtitle?: string;
  baseDt: string;
  checkerNm: string;
  writerNm?: string;
  // 작성자 로그인 ID — 서명 조회. 입력란 없음
  writerId?: string;
  // 작성자 서명 여부 Y|N
  writerSignYn?: string;
  approverNm?: string;
  // 점검자 로그인 ID — 서명 조회
  checkerId?: string;
  // 점검자 서명 스냅샷 여부 Y|N
  checkerSignYn?: string;
  // 승인자 로그인 ID
  approverId?: string;
  // 승인자 서명 스냅샷 여부 Y|N
  approverSignYn?: string;
  // 확인 로그인 ID — 풋터
  confirmId?: string;
  // 확인 서명 스냅샷 여부 Y|N
  confirmSignYn?: string;
}

export interface HtmlFormFooter {
  specialNote: string;
  improveNote: string;
  actionNm: string;
  confirmNm: string;
}

/** 지면 제목·부제·표 사이 캡션 — 점검 행이 아니다. item_cd varchar(20) */
export const PAPER_HDR = {
  TITLE: "hdr-title",
  SUBTITLE: "hdr-subtitle",
  SENS_CAP: "hdr-sens-cap",
  // 기록 표와 다음 표 사이 — 높이는 감도 캡션과 같다
  GAP_CAP: "hdr-gap-cap",
} as const;

/** 부제 기본 — 화면 Rule PAPER_SUBTITLE 이 비었을 때. 검증점검은 매월 */
export const PAPER_DEFAULT_SUBTITLE = "(매일 작성)";

/** 본문 표에서 빼는 메타 항목 */
export function isPaperHdrItem(
  // 항목코드
  itemCd: string,
): boolean {
  return (Object.values(PAPER_HDR) as string[]).includes(itemCd);
}

/** 점검 행만 — 제목·부제·캡션 제외 */
export function paperBodyItems(
  // 양식 항목 전체
  items: HtmlFormItem[],
): HtmlFormItem[] {
  return items.filter((row) => !isPaperHdrItem(row.itemCd));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 기준관리 수정·작성 편집 가능 여부를 한곳에서 정한다
 *   2) 공정점검·포장·가열·금속 지면이 같이 쓴다
 *   3) 표준 잠금이면 templateEdit 는 false
 */
export function htmlFormPaperEdit(
  // 기준관리=template, 작성=write
  mode: HtmlFormPaperMode,
  // 표준 잠금
  locked: boolean,
  // 셀 편집 권한
  editable: boolean,
  // 기준관리 수정 버튼 이후
  editing?: boolean,
): { templateEdit: boolean; writeEdit: boolean; writeView: boolean } {
  return {
    templateEdit: mode === "template" && !!editing && editable && !locked,
    writeEdit: mode === "write" && editable,
    /**
     * 저장된 실제 데이터를 그리는가 — 고칠 수 있는가와 다른 축이다.
     * 전송한 문서·결재 미리보기는 editable=false 지만 값은 그대로 보여야 한다.
     * 이 둘을 한 조건으로 묶으면 잠긴 문서가 빈 예시 지면으로 보인다.
     */
    writeView: mode === "write",
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) HTML radio 에는 readonly 가 없다. disabled 는 인쇄·미리보기에서 흐려진다
 *   2) 잠금이면 포커스·클릭만 막고 점은 검정으로 남긴다
 *   3) 문서함 미리보기·인쇄가 같이 탄다
 */
export function paperRadioLock(
  // 작성 중이면 true — 그때는 잠그지 않는다
  editable: boolean,
): {
  tabIndex?: number;
  "aria-disabled"?: boolean;
  className?: string;
  onMouseDown?: (e: { preventDefault: () => void }) => void;
} {
  if (editable) return {};
  return {
    tabIndex: -1,
    "aria-disabled": true,
    className: "html-form-radio-lock",
    onMouseDown: (e) => {
      e.preventDefault();
    },
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 적합/부적합 헤더 문구를 공통코드 JUDGE_PF 에서 읽는다
 *   2) 포장·가열·금속 기록 표가 같이 쓴다
 *   3) 코드 없으면 적합·부적합
 */
export function useJudgePfLabels(): { passNm: string; failNm: string } {
  const judgePf = useCommonCodes(JUDGE_PF_MAIN_CD);
  return {
    // P = 적합
    passNm: judgePf.label("P", "적합"),
    // F = 부적합
    failNm: judgePf.label("F", "부적합"),
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) item_cd 한 건을 찾는다
 *   2) 포장·가열·금속 한계기준 칸이 쓴다
 *   3) 없으면 undefined
 */
export function htmlFormItemOf(
  // 양식 항목 전체
  items: HtmlFormItem[],
  // item_cd
  cd: string,
): HtmlFormItem | undefined {
  return items.find((row) => row.itemCd === cd);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) item_cd 의 itemNm
 *   2) 없으면 빈 문자열
 *   3) 한계기준 값 칸이 쓴다
 */
export function htmlFormItemNm(
  // 양식 항목 전체
  items: HtmlFormItem[],
  // item_cd
  cd: string,
): string {
  return htmlFormItemOf(items, cd)?.itemNm ?? "";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) item_cd 한 건만 패치한다
 *   2) onItemsChange 없으면 no-op
 *   3) 공정점검·포장·가열·금속이 같이 쓴다
 */
export function patchHtmlFormItem(
  // 양식 항목 전체
  items: HtmlFormItem[],
  // 대상 item_cd
  itemCd: string,
  // 덮어쓸 필드
  patch: Partial<HtmlFormItem>,
  // 항목 배열 교체
  onItemsChange?: (next: HtmlFormItem[]) => void,
): void {
  if (!onItemsChange) return;
  onItemsChange(items.map((row) => (row.itemCd === itemCd ? { ...row, ...patch } : row)));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) item_cd 여러 건을 한 번에 패치한다
 *   2) 한계기준 한 칸 저장 때 나머지 한계 행 itemNm 을 비운다
 *   3) 한 번만 onItemsChange 해서 앞 패치가 덮이지 않게 한다
 */
export function patchHtmlFormItemNms(
  // 양식 항목 전체
  items: HtmlFormItem[],
  // item_cd → itemNm
  nms: Record<string, string>,
  // 항목 배열 교체
  onItemsChange?: (next: HtmlFormItem[]) => void,
): void {
  if (!onItemsChange) return;
  onItemsChange(items.map((row) => (row.itemCd in nms ? { ...row, itemNm: nms[row.itemCd] } : row)));
}

/** 메타 항목 문구. 없으면 fallback */
export function paperHdrNm(
  // 양식 항목 전체
  items: HtmlFormItem[],
  // hdr-title / hdr-subtitle / hdr-sens-cap / hdr-gap-cap
  cd: string,
  // 시드·화면 기본 문구
  fallback: string,
): string {
  const row = htmlFormItemOf(items, cd);
  if (row) return row.itemNm ?? "";
  return fallback;
}

/** 메타 항목 문구 저장. 없으면 행을 붙인다 */
export function patchPaperHdr(
  // 양식 항목 전체
  items: HtmlFormItem[],
  // hdr-title / hdr-subtitle / hdr-sens-cap / hdr-gap-cap
  cd: string,
  // 새 문구
  itemNm: string,
  // 항목 배열 교체
  onItemsChange?: (next: HtmlFormItem[]) => void,
): void {
  if (!onItemsChange) return;
  if (items.some((row) => row.itemCd === cd)) {
    onItemsChange(items.map((row) => (row.itemCd === cd ? { ...row, itemNm } : row)));
    return;
  }
  onItemsChange([
    ...items,
    {
      itemCd: cd,
      sortNo: 0,
      cycleNm: "",
      grpNm: "hdr",
      itemNm,
      inputType: "text",
    },
  ]);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 결재란 왼쪽 제목·부제. 수정 모드면 입력
 *   2) 저장은 hdr-title / hdr-subtitle 항목. 없으면 양식명(header.title). 작성 목록 식별 제목은 안 쓴다
 *   3) 5개 HTML 지면이 같이 쓴다
 */
export function PaperTitleCell({
  // 화면 기본 제목·부제 — title 은 양식명. 식별용 tbl_document.title 이 아니다
  header,
  // 양식 항목 — hdr-title 이 있으면 그걸 쓴다. 없으면 header.title(양식명)

  items,
  // 기준관리 수정 중
  templateEdit,
  // 항목 배열 교체
  onItemsChange,
}: {
  header: HtmlFormHeader;
  items: HtmlFormItem[];
  templateEdit: boolean;
  onItemsChange?: (next: HtmlFormItem[]) => void;
}) {
  const title = paperHdrNm(items, PAPER_HDR.TITLE, header.title);
  const subtitle = paperHdrNm(items, PAPER_HDR.SUBTITLE, header.subtitle || "");
  return (
    <>
      {templateEdit ? (
        <textarea
          // 지면 제목 — 자사 양식만. 여러 줄 허용
          className="html-form-title-input html-form-pre"
          rows={2}
          value={title}
          onChange={(e) => patchPaperHdr(items, PAPER_HDR.TITLE, e.target.value, onItemsChange)}
        />
      ) : (
        <div className="html-form-title">{title}</div>
      )}
      {templateEdit ? (
        <textarea
          // 부제 — (매일 작성) 등
          className="html-form-subtitle-input html-form-pre"
          rows={1}
          value={subtitle}
          onChange={(e) => patchPaperHdr(items, PAPER_HDR.SUBTITLE, e.target.value, onItemsChange)}
        />
      ) : (
        <div className="html-form-subtitle">{subtitle}</div>
      )}
    </>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 제목·결재·일자·점검자. 작성·수정이 같은 표·같은 칸 크기
 *   2) 일자 라벨만 화면이 넘긴다. 작성 모드 일자는 표시만 — 수정은 왼쪽 그리드
 *   3) 5개 HTML 지면이 같이 쓴다
 */
export function HtmlFormBanner({
  // 제목·부제·일자·서명
  header,
  // 저장된 제목·부제
  items,
  // 기준관리=template, 작성=write
  mode,
  // 기준관리 수정 중
  templateEdit,
  // 작성 편집
  writeEdit,
  // 작성일자 / 점검일자
  dateLabel,
  onHeaderChange,
  onItemsChange,
}: {
  header: HtmlFormHeader;
  items: HtmlFormItem[];
  mode: HtmlFormPaperMode;
  templateEdit: boolean;
  writeEdit: boolean;
  dateLabel: string;
  onHeaderChange?: (patch: Partial<HtmlFormHeader>) => void;
  onItemsChange?: (next: HtmlFormItem[]) => void;
}) {
  return (
    <table
      // 제목·결재·일자 전용. 본문 열 폭과 섞이지 않게 분리
      className="html-form-table html-form-banner"
    >
      <thead>
        <tr>
          <th
            // 제목+부제 — 결재란 왼쪽
            colSpan={3}
            rowSpan={2}
            className="html-form-title-cell"
          >
            <PaperTitleCell
              // 제목·부제 — 수정 때 입력
              header={{ ...header, subtitle: header.subtitle || PAPER_DEFAULT_SUBTITLE }}
              items={items}
              templateEdit={templateEdit}
              onItemsChange={onItemsChange}
            />
          </th>
          <th
            // 결재 세로칸
            rowSpan={2}
            className="html-form-stamp-role"
          >
            결재
          </th>
          <th className="html-form-stamp">작성자</th>
          <th className="html-form-stamp">승인자</th>
        </tr>
        <tr>
          <td className="html-form-stamp-cell">
            <SignSlot
              // 작성자 — 서명 있으면 이미지, 없으면 이름
              name={header.writerNm || ""}
              userId={header.writerId}
              signYn={header.writerSignYn}
              editable={false}
            />
          </td>
          <td className="html-form-stamp-cell">
            <SignSlot
              // 승인자
              name={header.approverNm || ""}
              userId={header.approverId}
              signYn={header.approverSignYn}
              editable={writeEdit}
              onChange={(value) => onHeaderChange?.({ approverNm: value })}
            />
          </td>
        </tr>
        <tr>
          <th>{dateLabel}</th>
          <td
            // 일자 값 — 라벨만 파랑
            colSpan={2}
          >
            {mode === "write" ? (
              <span
                // 작성일자는 왼쪽 목록 baseDtDisp 만 고친다. 지면에서 지우면 저장값이 비었다
                className="html-form-sign-input"
              >
                {header.baseDt}
              </span>
            ) : (
              header.baseDt
            )}
          </td>
          <th>점검자</th>
          <td colSpan={2}>
            <SignSlot
              // 점검자 — 서명 있으면 이미지, 없으면 이름
              name={header.checkerNm}
              userId={header.checkerId}
              signYn={header.checkerSignYn}
              editable={writeEdit}
              onChange={(value) => onHeaderChange?.({ checkerNm: value })}
            />
          </td>
        </tr>
      </thead>
    </table>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 개선조치 방법 한 행. 포장·가열·금속이 같이 쓴다
 *   2) 칸 높이(ccp-pkg-long)는 세 지면이 같다. 문구만 다르다
 *   3) 공정점검·검증점검은 풋터만 쓴다
 */
export function CcpCorrectiveBlock({
  // 저장된 조치 문구
  value,
  // 기준관리 수정 중
  templateEdit,
  // itemNm 패치
  onChange,
}: {
  value: string;
  templateEdit: boolean;
  onChange: (next: string) => void;
}) {
  return (
    <table className="html-form-table html-form-body">
      <tbody>
        <tr>
          <th className="html-form-axis ccp-pkg-axis">개선조치 방법</th>
          <td>
            {templateEdit ? (
              <textarea
                // 이탈 시 조치 문구. 글이 많으면 칸이 늘어난다
                className="html-form-cell-ta html-form-pre ccp-pkg-long"
                value={value}
                onChange={(e) => onChange(e.target.value)}
              />
            ) : (
              <span className="html-form-pre ccp-pkg-long">{value}</span>
            )}
          </td>
        </tr>
      </tbody>
    </table>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 하단 4열. 입력 칸 높이(html-form-foot)는 전 지면이 같다
 *   2) 첫 열·조치 열 제목만 화면이 넘긴다. 값은 footer
 *   3) 포장·가열·금속·공정점검·검증점검이 같이 쓴다
 */
export function HtmlFormFootTable({
  // 확인 서명 조회
  header,
  // 이탈·조치 값
  footer,
  // 작성 편집
  writeEdit,
  // 한계기준 이탈내용 / 특이사항
  noteLabel,
  // 조치자 / 조치
  actionLabel,
  onFooterChange,
}: {
  header: HtmlFormHeader;
  footer: HtmlFormFooter;
  writeEdit: boolean;
  noteLabel: string;
  actionLabel: string;
  onFooterChange?: (patch: Partial<HtmlFormFooter>) => void;
}) {
  return (
    <table className="html-form-table html-form-foot">
      <thead>
        <tr>
          <th className="html-form-foot-note">{noteLabel}</th>
          <th className="html-form-foot-improve">개선조치 및 결과</th>
          <th className="html-form-foot-sign">{actionLabel}</th>
          <th className="html-form-foot-sign">확인</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>
            <textarea
              // 첫 열 — 작성만 입력. 기준관리는 미리보기
              className="html-form-foot-input html-form-pre"
              /*
               * 이 넷은 표가 가로로 잘리면 머리글이 화면 밖으로 나간다.
               * 무슨 칸인지 몰라 운송온도를 확인 칸에 넣은 일이 있었다 —
               * 마우스를 올리면 칸 이름이 보이게 한다.
               *
               * 첫 칸은 특히 조심해야 한다. 여기에 글자가 있으면 개선조치가 자동으로 생긴다
               * (`sp_tbl_doc_corrective_u_000`). 「없음」이라고 써도 한 건으로 잡힌다 —
               * 실제로 그렇게 생긴 개선조치가 둘 있었다. 그 규칙을 칸에 적어 둔다.
               */
              title={`${noteLabel} — 여기에 글자를 쓰면 개선조치가 자동으로 생깁니다. 이탈이 없으면 비워 둡니다`}
              // 전송이 이탈내용에서 막히면 여기로 커서를 옮긴다 — focusBlockedCell 선택자와 짝
              data-deviation-note
              value={footer.specialNote}
              readOnly={!writeEdit}
              onChange={(e) => onFooterChange?.({ specialNote: e.target.value })}
            />
          </td>
          <td>
            <textarea
              // 개선조치 및 결과
              className="html-form-foot-input html-form-pre"
              title="개선조치 및 결과 — 이탈에 어떻게 조치했는지"
              value={footer.improveNote}
              readOnly={!writeEdit}
              onChange={(e) => onFooterChange?.({ improveNote: e.target.value })}
            />
          </td>
          <td>
            <input
              // 조치자·조치
              className="html-form-foot-input"
              title={`${actionLabel} — 조치한 사람`}
              value={footer.actionNm}
              readOnly={!writeEdit}
              onChange={(e) => onFooterChange?.({ actionNm: e.target.value })}
            />
          </td>
          <td>
            <SignSlot
              // 확인 — 서명 있으면 이미지
              name={footer.confirmNm}
              userId={header.confirmId}
              signYn={header.confirmSignYn}
              // 측정값 칸으로 오해해 온도를 넣은 일이 있다 — 사람 이름 칸임을 밝힌다
              title="확인 — 확인한 사람 이름. 측정값을 넣는 칸이 아닙니다"
              editable={writeEdit}
              onChange={(value) => onFooterChange?.({ confirmNm: value })}
            />
          </td>
        </tr>
      </tbody>
    </table>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 포장·가열 한계기준 2건을 한 칸 문자열로 만든다
 *   2) 시드 2행이면 `항목명 : 값` 을 줄바꿈으로 잇는다. 수정 후 1행이면 그대로
 *   3) trim 하면 Enter 개행이 사라져서 쓰지 않는다
 */
function joinLimitText(
  // 한계기준 행 — label 은 기록 표 열 제목(cycleNm)
  rows: { label?: string; itemNm: string }[],
): string {
  const filled = rows.filter((row) => (row.itemNm ?? "") !== "");
  if (filled.length === 0) return "";
  if (filled.length === 1) return filled[0].itemNm;
  return filled.map((row) => {
    const label = (row.label || "").trim();
    return label ? `${label} : ${row.itemNm}` : row.itemNm;
  }).join("\n");
}

/** 한계기준·주기·방법 한 칸 — 수정이면 textarea */
function CcpTextCell({
  // 저장된 문구
  value,
  // 기준관리 수정 중
  templateEdit,
  // 주기·방법·한계기준처럼 여러 줄
  long = false,
  // itemNm 패치
  onChange,
}: {
  value: string;
  templateEdit: boolean;
  long?: boolean;
  onChange: (next: string) => void;
}) {
  const cls = long ? "html-form-cell-ta html-form-pre ccp-pkg-long" : "html-form-cell-ta html-form-pre";
  if (templateEdit) {
    return (
      <textarea
        // 자사 양식만 입력. Enter 는 개행. 글이 많으면 칸이 늘어난다
        className={cls}
        cols={1}
        rows={2}
        value={value}
        onKeyDown={(e) => {
          if (e.key === "Enter") e.stopPropagation();
        }}
        onChange={(e) => onChange(e.target.value)}
      />
    );
  }
  return <span className={long ? "html-form-pre ccp-pkg-long" : "html-form-pre"}>{value}</span>;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 포장·가열·금속 한계기준은 한 칸 텍스트. 포장·가열 2건은 줄바꿈
 *   2) 주기·방법도 같은 표. 글이 많으면 ccp-pkg-long 이 칸을 키운다
 *   3) 세 지면이 같이 쓴다
 */
export function CcpLimitHeaderTable({
  // 한계기준 값 — 포장·가열은 온도·시간 2건을 한 칸으로 합친다
  limitRows,
  // 주기 item_cd·문구
  cycle,
  // 방법 item_cd·문구
  method,
  // 기준관리 수정 중
  templateEdit,
  // itemNm 패치 — 한계 한 칸이면 나머지 한계 행은 빈칸
  onPatch,
}: {
  limitRows: { cd: string; itemNm: string; label?: string }[];
  cycle: { cd: string; itemNm: string };
  method: { cd: string; itemNm: string };
  templateEdit: boolean;
  onPatch: (nms: Record<string, string>) => void;
}) {
  const first = limitRows[0];
  const limitText = joinLimitText(limitRows);
  return (
    <table
      // 한계기준·주기·방법
      className="html-form-table html-form-body"
    >
      <colgroup>
        <col className="ccp-pkg-axis" />
        <col />
      </colgroup>
      <tbody>
        <tr>
          <th
            // 한계기준 세로 라벨 — 값 한 칸
            className="html-form-axis"
          >
            한계기준
          </th>
          <td>
            <CcpTextCell
              // 한계기준 값 — 2건이면 항목명 : 값 두 줄. Enter 개행 유지
              value={limitText}
              templateEdit={templateEdit}
              long
              onChange={(next) => {
                if (!first) return;
                const nms: Record<string, string> = { [first.cd]: next };
                for (const row of limitRows.slice(1)) nms[row.cd] = "";
                onPatch(nms);
              }}
            />
          </td>
        </tr>
        <tr>
          <th className="html-form-axis">주기</th>
          <td>
            <CcpTextCell
              // 점검 주기
              value={cycle.itemNm}
              templateEdit={templateEdit}
              long
              onChange={(next) => onPatch({ [cycle.cd]: next })}
            />
          </td>
        </tr>
        <tr>
          <th className="html-form-axis">방법</th>
          <td>
            <CcpTextCell
              // 모니터링 방법
              value={method.itemNm}
              templateEdit={templateEdit}
              long
              onChange={(next) => onPatch({ [method.cd]: next })}
            />
          </td>
        </tr>
      </tbody>
    </table>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 기록 표와 한계기준 사이를 벌린다. 금속은 시드 제목, 포장·가열은 빈칸
 *   2) 수정 때 입력. 저장은 hdr-sens-cap
 *   3) 세 CCP 일지가 같이 쓴다
 */
export function CcpLogCaption({
  // 양식 항목
  items,
  // 시드·빈칸
  fallback,
  // 기준관리 수정 중
  templateEdit,
  // 항목 배열 교체
  onItemsChange,
}: {
  items: HtmlFormItem[];
  fallback: string;
  templateEdit: boolean;
  onItemsChange?: (next: HtmlFormItem[]) => void;
}) {
  const cap = paperHdrNm(items, PAPER_HDR.SENS_CAP, fallback);
  return (
    <caption
      // 기록 표 위 제목·간격
      className="ccp-mtl-cap"
    >
      {templateEdit ? (
        <input
          // 캡션 — 포장·가열은 빈칸으로 시작
          className="ccp-mtl-cap-input"
          value={cap}
          onChange={(e) => patchPaperHdr(items, PAPER_HDR.SENS_CAP, e.target.value, onItemsChange)}
        />
      ) : (
        cap || "\u00a0"
      )}
    </caption>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 기록 표와 다음 표 사이. 높이는 감도 캡션(ccp-mtl-cap)과 같다
 *   2) 수정 때 문구 입력. 저장은 hdrCd(기본 hdr-gap-cap). 행 추가 버튼은 인쇄 숨김
 *   3) 포장·가열·공정·검증은 fallback 빈칸. 금속만 통과량 제목 기본 문구
 */
export function HtmlFormRowAddSlot({
  // 양식 항목
  items,
  // 기준관리 수정 중
  templateEdit,
  // 항목 배열 교체
  onItemsChange,
  // 저장 item_cd — 기본 표 사이 간격
  hdrCd = PAPER_HDR.GAP_CAP,
  // 저장된 행이 없을 때 보여줄 문구. 금속 통과량 제목
  fallback = "",
  // 행 추가 버튼. 없으면 캡션만
  children,
}: {
  items: HtmlFormItem[];
  templateEdit: boolean;
  onItemsChange?: (next: HtmlFormItem[]) => void;
  hdrCd?: string;
  fallback?: string;
  children?: ReactNode;
}) {
  const cap = paperHdrNm(items, hdrCd, fallback);
  return (
    <div
      // 감도 캡션과 같은 높이. 문구는 인쇄한다
      className="html-form-row-add"
    >
      {templateEdit ? (
        <input
          // 표 사이 문구 — 비어 있으면 간격만
          className="ccp-mtl-cap-input"
          value={cap}
          onChange={(e) => patchPaperHdr(items, hdrCd, e.target.value, onItemsChange)}
        />
      ) : (
        <span className="ccp-mtl-cap-input">{cap || "\u00a0"}</span>
      )}
      {children ? (
        <div
          // 행 추가 — 인쇄 숨김
          className="html-form-no-print"
        >
          {children}
        </div>
      ) : null}
    </div>
  );
}

/** 작업 전/작업 종료 구분 — DB phase_cd. 지면 행 추가 버튼이 이 값으로 영역을 가른다 */
export const LOG_PHASE = {
  BEFORE: "BEFORE",
  AFTER: "AFTER",
} as const;
export type LogPhase = (typeof LOG_PHASE)[keyof typeof LOG_PHASE];

/**
 * 기록 표 1행 — CCP 포장·가열 기록표와 금속 감도표가 같이 쓴다.
 * 양식마다 다른 칸(온도·분·초·Fe만·SUS만 …)은 cells 에 item_cd → 값으로 담는다.
 * BE 가 계열별로 cells 를 실제 컬럼(generic _cell · metal sens_row)으로 편다.
 */
export interface HtmlFormLogRow {
  // 저장 순번 — 영역 안 정렬. 신규 행은 화면이 뒤에 붙인다
  rowSeq: number;
  // 작업 전/작업 종료 — 이 값으로만 영역을 가른다. DOM 위치로 판단하지 않는다
  phaseCd: LogPhase;
  // 품명 — 고정 라벨 행(작업 전/작업 종료)은 화면이 라벨을 대신 그린다
  productNm: string;
  // 측정시각·통과시간
  checkTime: string;
  // 판정 P=적합 F=부적합. 빈값이면 미판정
  judgeCd: string;
  /*
   * 판정 수동수정 여부 Y/N — **지금은 쓰이지 않는다. 항상 N 이다.**
   *
   * 금속검출만 서버가 감도 5칸으로 판정을 계산하고 이 값이 Y 면 사람 값이 이겼다.
   * 그 자동 판정을 걷어냈다 — 판정은 다섯 화면 모두 사람이 정한다.
   * DB 칸(judge_mod_yn NOT NULL)이 남아 있어 왕복만 시킨다. 새로 Y 를 붙이지 않는다.
   */
  judgeModYn?: string;
  // 행 서명 이름
  checkerNm: string;
  // 서명 이미지 스냅샷 여부 Y/N
  signYn: string;
  // 양식별 입력칸 — 예: PKG temp·min·sec / HTG temp·time / MTL fe-only·sts-only…
  cells: Record<string, string>;
  // 영역 첫 줄 고정 라벨 행 여부 — 작업 전/작업 종료. 삭제 불가
  fixedYn?: string;
}

/** 금속검출 통과량 표 1행 — MTL 두 번째 표 전용 */
export interface HtmlFormPassRow {
  rowSeq: number;
  // 품명
  productNm: string;
  // 통과량
  passQty: string;
  // 검출량
  detectQty: string;
  // 특이사항
  remark: string;
}

export interface HtmlFormPaperProps {
  // 기준관리=template, 작성=write
  mode: HtmlFormPaperMode;
  // 표준이면 항목 잠금
  locked: boolean;
  // 작성·기준관리 입력 가능
  editable: boolean;
  // 기준관리 수정 버튼 이후만 셀 편집
  editing?: boolean;
  // a4=인쇄 폭, fill=패널 채움
  variant?: HtmlFormPaperVariant;
  // 상단 제목·일자·점검자·결재
  header: HtmlFormHeader;
  // 점검 행
  items: HtmlFormItem[];
  // 하단 4열 — 특이사항·개선조치 및 결과·조치·확인
  footer: HtmlFormFooter;
  onHeaderChange?: (patch: Partial<HtmlFormHeader>) => void;
  onItemsChange?: (items: HtmlFormItem[]) => void;
  onFooterChange?: (patch: Partial<HtmlFormFooter>) => void;
  /**
   * 기록 표 행 — mode="write" 에서만 쓴다.
   * 넘기지 않으면(= 기준관리 미리보기) 지면이 예전처럼 빈 예시 행을 고정으로 그린다.
   */
  logRows?: HtmlFormLogRow[];
  onLogRowsChange?: (rows: HtmlFormLogRow[]) => void;
  /** 금속검출 통과량 표 행 — MTL 작성에서만 쓴다 */
  passRows?: HtmlFormPassRow[];
  onPassRowsChange?: (rows: HtmlFormPassRow[]) => void;
  selectedIndex?: number | null;
  onSelectIndex?: (index: number) => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 한 영역(작업 전/작업 종료)의 행만 순서대로 뽑는다
 *   2) 지면이 영역별로 행을 그릴 때 호출한다
 *   3) logRows 가 없으면(= 기준관리 미리보기) 빈 배열
 */
export function logRowsOf(
  // 기록 행 전체
  rows: HtmlFormLogRow[] | undefined,
  // 뽑을 영역
  phase: LogPhase,
): HtmlFormLogRow[] {
  return (rows ?? []).filter((r) => r.phaseCd === phase).sort((a, b) => a.rowSeq - b.rowSeq);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 영역 첫 줄(작업 전·작업 종료 라벨 행)인지 — 지면이 `idx === 0` 으로 그리는 그 행이다
 *   2) 지면과 전송 검증이 같이 쓴다. 두 군데서 따로 판단하면 어긋난다
 *   3) 그 행은 품명 자리에 화면이 라벨을 대신 그린다 — 사람이 채울 칸이 없다
 *
 * 행에 `fixedYn` 칸이 있지만 **아무도 채우지 않는다.** 그 값을 믿으면 전 행이 라벨이 아닌 것으로 잡힌다.
 */
export function isFixedLabelRow(
  // 기록 행 전체
  rows: HtmlFormLogRow[],
  // 판단할 행
  row: HtmlFormLogRow,
): boolean {
  const first = logRowsOf(rows, row.phaseCd)[0];
  return !!first && first.rowSeq === row.rowSeq;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 지정한 영역 끝에 빈 행을 붙인다 — 다른 영역 행은 건드리지 않는다
 *   2) 영역별 「행 추가」 버튼이 호출한다
 *   3) rowSeq 는 전체 최대값+1 이라 영역이 섞여도 키가 겹치지 않는다
 */
export function appendLogRow(
  // 기록 행 전체
  rows: HtmlFormLogRow[],
  // 붙일 영역
  phase: LogPhase,
  /*
   * 새 행의 판정. 기본은 적합이다 — 현장 기록은 대부분이 적합이라
   * 빈 값으로 두면 행마다 라디오를 한 번씩 더 눌러야 한다.
   *
   * 금속검출도 이제 같다. 예전에는 빈 값("")을 넘겼다 — 서버가 감도 5칸으로 자동 판정해서
   * 화면이 미리 칠해 봐야 저장하면 뒤집혔기 때문이다. 그 자동 판정을 걷어냈다.
   * 판정은 다섯 화면 모두 **사람이 정하고 그대로 저장된다.**
   */
  judgeCd: string = JUDGE.PASS,
): HtmlFormLogRow[] {
  const nextSeq = rows.reduce((max, r) => Math.max(max, r.rowSeq), 0) + 1;
  return [...rows, {
    rowSeq: nextSeq,
    phaseCd: phase,
    productNm: "",
    checkTime: "",
    judgeCd,
    judgeModYn: "N",
    checkerNm: "",
    signYn: "N",
    cells: {},
  }];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 기록 행 한 건을 부분 수정한다
 *   2) 지면 입력 onChange 가 호출한다
 *   3) rowSeq 로 찾는다 — 영역이 달라도 rowSeq 는 유일하다
 */
/** 판정 코드 — P=적합 F=부적합. 문자열을 여기저기 박지 않는다 */
export const JUDGE = { PASS: "P", FAIL: "F" } as const;

/** 항목 판정 — Y=적합(예) N=부적합(아니오) */
export const ITEM_YN = { PASS: "Y", FAIL: "N" } as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 기록 행 전부를 적합으로 바꾼다
 *   2) 지면의 「모두 적합」 버튼이 호출한다
 *   3) 이미 적합인 행·이미 찍힌 O/X 도 적합 모양으로 덮는다 — 되돌리기는 행마다 부적합을 누르면 된다
 */
export function allLogRowsPass(
  // 기록 행 전체
  rows: HtmlFormLogRow[],
  /*
   * 같이 채울 입력칸 — 금속검출 감도 5칸처럼 「적합이면 이 모양」이 정해진 칸이 있을 때 준다.
   *
   * 판정만 적합으로 바꾸면 **근거는 비었는데 결론만 적합인 종이**가 나온다.
   * 실제로 감도 5칸이 전부 X(시편이 검출 안 됨 = 검출기 고장)인데
   * 판정만 적합인 기록이 운영에 남아 있었다.
   * 부르는 쪽이 「적합일 때의 값」을 알고 있으니 여기서 같이 채운다.
   */
  passCells?: Record<string, string>,
  /*
   * **고정행에서만** 「해당 없음」인 칸 — 그 행에서는 안 채운다.
   *
   * 「해당 없음」은 양식이 **열 단위**로 정하지만, 지면은 `fixed && na` 일 때만 그렇게 그린다.
   * 사람이 더한 행에는 그 열에도 입력칸이 있다.
   * 열 단위로 빼 버리면 **사람이 더한 행의 근거 칸이 빈 채로 판정만 적합**이 된다 —
   * 이 인자가 막으려던 바로 그 모양이다. 운영 확인에서 실제로 그렇게 났다.
   */
  naOnFixed?: string[],
): HtmlFormLogRow[] {
  const naSet = new Set(naOnFixed ?? []);
  return rows.map((r) => {
    if (!passCells) return { ...r, judgeCd: JUDGE.PASS };
    const fill = isFixedLabelRow(rows, r)
      ? Object.fromEntries(Object.entries(passCells).filter(([cd]) => !naSet.has(cd)))
      : passCells;
    return {
      ...r,
      judgeCd: JUDGE.PASS,
      // 부적합으로 찍힌 O/X 도 적합 모양으로 덮는다 — 「모두 적합」은 일괄이다
      cells: applyPassCells(r.cells, fill),
    };
  });
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-02
 * 코멘트:
 *   1) 적합일 때의 칸 값을 빈 칸·이미 찍힌 칸 모두에 넣는다
 *   2) allLogRowsPass 가 「모두 적합」에서 호출한다
 *   3) 값이 있어도 덮는다 — 부적합 O/X 를 적합으로 되돌리기 위함이다
 */
function applyPassCells(
  // 지금 행의 칸
  cells: Record<string, string>,
  // 적합일 때의 값
  passCells: Record<string, string>,
): Record<string, string> {
  return { ...cells, ...passCells };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 판정 칸이 있는 점검 항목 전부를 적합(예)으로 바꾼다
 *   2) 공정점검·검증점검 지면의 「모두 적합」 버튼이 호출한다
 *   3) 라디오가 없는 항목(숫자·문자 전용)과 표 머리글 행은 건드리지 않는다
 */
export function allItemsPass(
  // 양식 항목 전체
  items: HtmlFormItem[],
): HtmlFormItem[] {
  return items.map((it) => (
    !isPaperHdrItem(it.itemCd)
      && htmlFormInputLayout(it.inputType).radio
      && it.yn !== ITEM_YN.PASS
      ? { ...it, yn: ITEM_YN.PASS }
      : it
  ));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) **비어 있는 판정만** 적합으로 채운다
 *   2) 지면을 열 때 호출한다 — 「모두 적합」 버튼(allLogRowsPass)과 다르다
 *   3) 이미 정해진 판정은 절대 안 건드린다. 저장해 둔 부적합을 적합으로 덮으면
 *      사람이 남긴 판정을 지우는 셈이다
 */
export function fillBlankLogJudges(
  // 기록 행 전체
  rows: HtmlFormLogRow[],
): HtmlFormLogRow[] {
  return rows.map((r) => (r.judgeCd ? r : { ...r, judgeCd: JUDGE.PASS }));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 판정 칸이 있는 항목 중 **비어 있는 것만** 적합(예)으로 채운다
 *   2) 지면을 열 때 호출한다
 *   3) 이미 예/아니오가 정해진 항목과 판정 칸이 없는 항목은 안 건드린다
 */
export function fillBlankItemJudges(
  // 양식 항목 전체
  items: HtmlFormItem[],
): HtmlFormItem[] {
  return items.map((it) => (
    !isPaperHdrItem(it.itemCd)
      && htmlFormInputLayout(it.inputType).radio
      && !it.yn
      ? { ...it, yn: ITEM_YN.PASS }
      : it
  ));
}

export function patchLogRow(
  // 기록 행 전체
  rows: HtmlFormLogRow[],
  // 대상 행 순번
  rowSeq: number,
  // 덮어쓸 칸
  patch: Partial<Omit<HtmlFormLogRow, "cells">> & { cells?: Record<string, string> },
): HtmlFormLogRow[] {
  return rows.map((r) => (r.rowSeq === rowSeq
    ? { ...r, ...patch, cells: patch.cells ? { ...r.cells, ...patch.cells } : r.cells }
    : r));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 행 추가로 만든 행을 뺀다
 *   2) 행 우측 삭제 버튼이 호출한다
 *   3) 고정 라벨 행(작업 전/작업 종료)은 호출부가 버튼을 안 그린다
 */
export function removeLogRow(
  // 기록 행 전체
  rows: HtmlFormLogRow[],
  // 지울 행 순번
  rowSeq: number,
): HtmlFormLogRow[] {
  return rows.filter((r) => r.rowSeq !== rowSeq);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 금속 통과량 표 끝에 빈 행을 붙인다
 *   2) 「금속검출기 제품 통과」 옆 행 추가 버튼이 호출한다
 *   3) rowSeq 는 최대값+1
 */
export function appendPassRow(
  // 통과량 행 전체
  rows: HtmlFormPassRow[],
): HtmlFormPassRow[] {
  const nextSeq = rows.reduce((max, r) => Math.max(max, r.rowSeq), 0) + 1;
  return [...rows, { rowSeq: nextSeq, productNm: "", passQty: "", detectQty: "", remark: "" }];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 통과량 행 한 건을 부분 수정한다
 *   2) 지면 입력 onChange 가 호출한다
 *   3) rowSeq 로 찾는다
 */
export function patchPassRow(
  // 통과량 행 전체
  rows: HtmlFormPassRow[],
  // 대상 행 순번
  rowSeq: number,
  // 덮어쓸 칸
  patch: Partial<HtmlFormPassRow>,
): HtmlFormPassRow[] {
  return rows.map((r) => (r.rowSeq === rowSeq ? { ...r, ...patch } : r));
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 저장 후 서명이 있으면 이미지를 그린다. 잠금 지면은 이름을 항상 남긴다
 *   2) 작성자·승인자·점검자·풋터 확인란이 쓴다
 *   3) Blob URL은 unmount 때 해제한다
 */
export function SignSlot({
  // 표시·입력 이름
  name,
  // 서명 조회용 사용자 ID — signYn=Y 일 때만
  userId,
  // 문서 스냅샷 여부 Y|N
  signYn,
  // 작성 편집
  editable,
  // 이름 변경 — 저장 전엔 텍스트만
  onChange,
  // 마우스 오버 설명 — 표가 잘려 머리글이 안 보일 때 이 칸이 뭔지 알려 준다
  title,
}: {
  name: string;
  userId?: string;
  signYn?: string;
  editable: boolean;
  onChange?: (value: string) => void;
  title?: string;
}) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    const id = (userId || "").trim();
    if (signYn !== "Y" || !id) {
      setUrl(null);
      return;
    }
    let objectUrl = "";
    let cancelled = false;
    // ponytail: 화면은 현재 사용자 서명을 받는다. 문서 bytea GET이 생기면 스냅샷으로 교체
    void fetchUserSignBlob(id)
      .then((blob) => {
        objectUrl = URL.createObjectURL(blob);
        if (cancelled) {
          URL.revokeObjectURL(objectUrl);
          return;
        }
        setUrl(objectUrl);
      })
      .catch(() => {
        if (!cancelled) setUrl(null);
      });
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [userId, signYn]);

  return (
    <div className="html-form-sign">
      {url ? (
        <img
          // 사용자 서명 이미지 — 저장 시점 스냅샷과 같은 사람
          src={url}
          alt=""
        />
      ) : null}
      {editable ? (
        <input
          // 이름 — 서명이 있어도 바꿀 수 있다. 저장하면 다시 매칭
          className="html-form-sign-input"
          // 표가 잘려 머리글이 안 보일 때 이 칸이 무엇인지 알려 준다
          title={title}
          value={name}
          onChange={(e) => onChange?.(e.target.value)}
        />
      ) : name ? (
        <span
          // 잠금 지면 — 서명이 있어도 이름을 남긴다. 서명 GET 실패 때 칸이 비지 않게
          className="html-form-pre"
        >
          {name}
        </span>
      ) : null}
    </div>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 지면 입력칸을 제어 입력으로 만드는 props 를 돌려준다
 *   2) 작성(mode="write") 지면의 행 컴포넌트에서 한 번 만들어 칸마다 편다
 *   3) row 가 없을 때(= 기존 template 미리보기)는 빈 객체다 — value 를 붙이지 않아 비제어 상태를 그대로 둔다
 *
 * 세 지면(포장·가열·금속검출)이 같은 코드를 갖고 있어 한 곳으로 모은다.
 */
export function inputBinder(
  // present: 이 행이 실제 데이터 행인지 — 미리보기 행이면 null/undefined
  present: unknown,
) {
  return (
    // get: 현재 값을 읽는다
    get: () => string,
    // set: 바뀐 값을 행에 반영한다
    set: (v: string) => void,
  ) =>
    present
      ? { value: get(), onChange: (e: { target: { value: string } }) => set(e.target.value) }
      : {};
}

/** 지면 입력칸 종류 — 정렬·허용 문자·입력기가 이 값 하나로 갈린다 */
export const CELL_KIND = {
  // 품명·특이사항 등 자유 문자 — 왼쪽 정렬
  TEXT: "text",
  // 온도·수량 등 수치 — 오른쪽 정렬. 숫자·소수점·부호만 통과한다
  NUM: "num",
  // 측정시각·통과시간 — 시:분 콤보
  TIME: "time",
  // 가열시간 등 소요시간 — 시:분 콤보 (초는 받지 않는다)
  DURATION: "duration",
} as const;
export type CellKind = (typeof CELL_KIND)[keyof typeof CELL_KIND];

/** 종류별 정렬 — 표 전체가 가운데로 몰리지 않게 한다 */
const CELL_ALIGN: Record<CellKind, string> = {
  text: "text-left",
  num: "text-right",
  time: "text-center",
  duration: "text-center",
};

/** 숫자칸 허용 문자 — 부호 1개, 숫자, 소수점 1개 */
const NUM_ALLOWED = /^-?\d*\.?\d*$/;

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 이 값을 칸에 넣어도 되는지 본다
 *   2) HtmlFormCellInput 의 onChange 가 호출한다
 *   3) 숫자칸만 거른다 — 한글 IME 로 들어온 글자를 여기서 막는다. 나머지 종류는 그대로 통과
 */
export function cellValueAccepted(
  // kind: 칸 종류
  kind: CellKind,
  // next: 입력기가 올린 값
  next: string,
): boolean {
  if (kind !== CELL_KIND.NUM) return true;
  return NUM_ALLOWED.test(next);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 지면 입력칸 하나를 종류에 맞는 입력기·정렬·검증으로 그린다
 *   2) 작성 지면(포장·가열·금속검출)의 모든 입력칸이 이것만 쓴다 — 칸마다 규칙이 갈리지 않게 한다
 *   3) 미리보기 행(row 없음)은 값을 붙이지 않아 기존 template 화면 모양이 그대로다
 *
 * type="number" 를 쓰지 않는 이유 — 한글 IME 로 입력하면 화면에는 글자가 남고 value 는 빈 문자열이 되어
 * 사용자가 쓴 값이 조용히 사라진다. text 로 받고 허용 문자만 통과시키면 그 경로가 막힌다.
 */
export function HtmlFormCellInput({
  // kind: 칸 종류 — 정렬·입력기·검증을 정한다
  kind,
  // value: 현재 값. 미리보기 행이면 undefined
  value,
  // onChange: 통과한 값만 올라온다
  onChange,
  // editable: 작성 모드에서 참
  editable,
  // title: 마우스 오버 설명 — 칸 이름
  title,
}: {
  kind: CellKind;
  value?: string;
  onChange?: (next: string) => void;
  editable: boolean;
  title?: string;
}) {
  // 미리보기 행일 때(= value 를 주지 않음) 비제어로 두어 기존 화면 모양을 유지한다
  const controlled = value !== undefined && !!onChange;
  const align = CELL_ALIGN[kind];
  const common = {
    className: `html-form-sign-input ${align}`,
    readOnly: !editable,
    title,
  };
  if (kind === CELL_KIND.TIME) {
    return (
      <DocCellTime
        // HTML type=time — 값은 HH:mm
        className={`html-form-sign-input ${align}`}
        // 작성 중이 아니면 고를 수 없다. disabled 는 인쇄·미리보기에서 흐려져서 readOnly 만 쓴다
        readOnly={!editable}
        // 칸 이름 — 시각
        title={title}
        // 지면 저장값은 HH:MM
        storage="hm"
        // 미리보기 행이면 빈 값. 작성 행이면 현재 시각
        value={controlled ? (value ?? "") : ""}
        // 작성 행만 버퍼로 올린다
        onChange={controlled ? (next) => onChange?.(next) : () => {}}
      />
    );
  }
  return (
    <input
      {...common}
      type="text"
      // 숫자칸은 모바일에서도 숫자 자판이 먼저 뜨게 한다
      inputMode={kind === CELL_KIND.NUM ? "decimal" : undefined}
      {...(controlled
        ? {
            value: value ?? "",
            onChange: (e) => {
              const next = e.target.value;
              // 숫자칸에 숫자·부호·소수점 외의 글자가 들어올 때(= 한글 IME 등) 이전 값을 지킨다
              if (!cellValueAccepted(kind, next)) return;
              onChange?.(next);
            },
          }
        : {})}
    />
  );
}
