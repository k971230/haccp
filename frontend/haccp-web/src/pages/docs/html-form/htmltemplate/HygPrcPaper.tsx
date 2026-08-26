/**
 * HygPrcPaper — 일반위생관리 및 공정점검표 지면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 공정점검·검증점검이 이 HTML 을 같이 쓴다. 제목·항목은 화면 데이터
 *   2) 작성은 A4. 기준관리는 fill. 조회는 주기·관리 rowspan. 수정 때 행을 끌어 순번(sortNo)을 바꾼다
 *   3) 헤더·풋터는 HtmlFormBanner·HtmlFormFootTable. 검증점검도 이 컴포넌트
 *
 * PIPELINE[HF130] 공정점검 지면
 */
// 역할 — 항목 패치 · 입력유형 레이아웃
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";
import {
  FALLBACK_HTML_INPUT_TY,
  HTML_INPUT_DEFAULT_TY,
  HTML_INPUT_DEFAULT_UNIT,
  htmlFormInputLayout,
  normalizeHtmlInputTy,
} from "@/api/docs/htmlFormApi";
// 역할 — 공통 지면 props · 결재 서명 슬롯
import {
  HtmlFormBanner,
  HtmlFormFootTable,
  HtmlFormRowAddSlot,
  htmlFormPaperEdit,
  isPaperHdrItem,
  paperBodyItems,
  patchHtmlFormItem,
  type HtmlFormPaperProps,
} from "@/components/form/htmlFormPaperShared";
// 역할 — 행 추가·삭제 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 행 순서 드래그 손잡이
import { GripVertical } from "lucide-react";
// 역할 — 공통코드 html-input-ty · judge-yn
import { HTML_INPUT_TY_MAIN_CD, JUDGE_YN_MAIN_CD, useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 드래그 출발 행
import { useRef, useState } from "react";

/** 연속 같은 값의 rowspan. 0 이면 셀 생략 */
function rowSpans(values: string[]): number[] {
  const spans = values.map(() => 0);
  let i = 0;
  while (i < values.length) {
    let j = i + 1;
    while (j < values.length && values[j] === values[i]) j += 1;
    spans[i] = j - i;
    i = j;
  }
  return spans;
}

/** 본문 행을 sortNo 순으로 */
function sortedBodyItems(items: HtmlFormItem[]): HtmlFormItem[] {
  return paperBodyItems(items)
    .slice()
    .sort((a, b) => (a.sortNo || 0) - (b.sortNo || 0) || a.itemCd.localeCompare(b.itemCd));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 점검 행만 순서를 바꾼다. 제목·부제 hdr 행은 앞에 둔다
 *   2) 드롭 위치 앞에 끼우고 sortNo 를 1부터 다시 매긴다
 *   3) 저장은 기존 items PUT. SP 가 sortNo 를 sort_no 에 쓴다
 */
function moveHtmlFormBody(
  // 양식 항목 전체
  items: HtmlFormItem[],
  // 끌어온 item_cd
  fromCd: string,
  // 놓은 item_cd
  toCd: string,
): HtmlFormItem[] {
  const hdr = items.filter((row) => isPaperHdrItem(row.itemCd));
  const body = sortedBodyItems(items);
  const from = body.findIndex((row) => row.itemCd === fromCd);
  const to = body.findIndex((row) => row.itemCd === toCd);
  if (from < 0 || to < 0 || from === to) return items;
  const next = [...body];
  const [row] = next.splice(from, 1);
  next.splice(to, 0, row);
  return [...hdr, ...next.map((item, i) => ({ ...item, sortNo: i + 1 }))];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) A4 표 한 장. 제목·결재 표와 본문 표를 나눈다
 *   2) 기준관리 hyg-process-template · ccp-verify-template 와 작성 hygiene-process-check 가 같은 컴포넌트를 쓴다
 *   3) 저장 API는 호출하지 않는다
 */
export function HygPrcPaper({
  // 기준관리 / 작성
  mode,
  // 표준 잠금
  locked,
  // 셀 편집
  editable,
  // 수정 모드
  editing = false,
  // 용지 폭
  variant = "a4",
  // 헤더
  header,
  // 행
  items,
  // 하단
  footer,
  onHeaderChange,
  onItemsChange,
  onFooterChange,
  selectedIndex,
  onSelectIndex,
}: HtmlFormPaperProps) {
  const inputTy = useCommonCodes(HTML_INPUT_TY_MAIN_CD);
  const judgeYn = useCommonCodes(JUDGE_YN_MAIN_CD);
  const dragCd = useRef<string | null>(null);
  const [overCd, setOverCd] = useState<string | null>(null);
  const typeOptions: { subCd: string; codeNm: string }[] =
    inputTy.codes.length > 0 ? inputTy.codes : [...FALLBACK_HTML_INPUT_TY];
  const yesNm = judgeYn.label("y", "예");
  const noNm = judgeYn.label("n", "아니오");
  const { templateEdit, writeEdit } = htmlFormPaperEdit(mode, locked, editable, editing);
  const bodyItems = sortedBodyItems(items);
  const cycleSpans = templateEdit ? bodyItems.map(() => 1) : rowSpans(bodyItems.map((row) => row.cycleNm || ""));
  const grpSpans = templateEdit ? bodyItems.map(() => 1) : rowSpans(bodyItems.map((row) => `${row.cycleNm}\t${row.grpNm}`));
  const colCount = templateEdit ? 5 : 6;

  const patchItem = (itemCd: string, patch: Partial<HtmlFormItem>) => {
    patchHtmlFormItem(items, itemCd, patch, onItemsChange);
  };

  const addRow = () => {
    if (!onItemsChange) return;
    const last = bodyItems[bodyItems.length - 1];
    onItemsChange([
      ...items,
      {
        itemCd: `hp-u-${Date.now()}`,
        sortNo: bodyItems.length + 1,
        cycleNm: last?.cycleNm ?? "",
        grpNm: last?.grpNm ?? "",
        itemNm: "",
        inputType: last ? normalizeHtmlInputTy(last.inputType) : HTML_INPUT_DEFAULT_TY,
        unitNm: last?.unitNm ?? "",
        yn: "",
        valNm: "",
      },
    ]);
  };

  const removeRow = (itemCd: string) => {
    if (!onItemsChange) return;
    const hdr = items.filter((row) => isPaperHdrItem(row.itemCd));
    const nextBody = bodyItems
      .filter((row) => row.itemCd !== itemCd)
      .map((row, i) => ({ ...row, sortNo: i + 1 }));
    onItemsChange([...hdr, ...nextBody]);
  };

  return (
    <article
      // A4 또는 패널 채움 — DocPaper 와 클래스 분리
      className={variant === "fill" ? "doc-paper-fill" : "doc-paper-a4"}
      aria-label="일반위생관리 및 공정점검표"
    >
      <HtmlFormBanner
        // 제목·결재·점검일자·점검자. 검증점검과 같은 표
        header={header}
        items={items}
        mode={mode}
        templateEdit={templateEdit}
        writeEdit={writeEdit}
        dateLabel="점검일자"
        onHeaderChange={onHeaderChange}
        onItemsChange={onItemsChange}
      />
      <table
        // 본문 — 수정 때 입력유형·삭제 열 비율은 html-form-body-edit
        className={cn("html-form-table html-form-body", templateEdit && "html-form-body-edit")}
      >
        <colgroup>
          {templateEdit ? (
            <>
              <col className="html-form-cycle-col" />
              <col className="html-form-grp-col" />
              <col className="html-form-item-col" />
              <col className="html-form-type-col" />
              <col className="html-form-row-col" />
            </>
          ) : (
            <>
              {/* 전체 10: 주기1 관리1 점검내용4 예1 아니오1 값2 */}
              <col className="html-form-cycle-col" />
              <col className="html-form-grp-col" />
              <col className="html-form-item-col" />
              <col className="html-form-yn-col" />
              <col className="html-form-yn-col" />
              <col className="html-form-val-col" />
            </>
          )}
        </colgroup>
        <thead>
          {templateEdit ? (
            <tr>
              <th className="html-form-cycle-col">주기</th>
              <th className="html-form-grp-col">관리</th>
              <th className="html-form-item-col">점검내용</th>
              <th className="html-form-type-col">입력유형</th>
              <th className="html-form-row-col html-form-no-print">행</th>
            </tr>
          ) : (
            <>
              <tr>
                <th rowSpan={2} className="html-form-cycle-col">주기</th>
                <th rowSpan={2} className="html-form-grp-col">관리</th>
                <th rowSpan={2} className="html-form-item-col">점검내용</th>
                <th
                  // 기록 — 예/아니오 위 병합. 폭은 예1+아니오1
                  colSpan={2}
                >
                  기록
                </th>
                <th rowSpan={2} className="html-form-val-col">값</th>
              </tr>
              <tr>
                <th className="html-form-yn-col">{yesNm}</th>
                <th className="html-form-yn-col">{noNm}</th>
              </tr>
            </>
          )}
        </thead>
        <tbody>
          {bodyItems.length === 0 ? (
            <tr>
              <td colSpan={colCount} className="py-6 text-center text-slate-500">
                점검항목이 없습니다.
              </td>
            </tr>
          ) : (
            bodyItems.map((item, index) => {
              const { radio, valueCell } = htmlFormInputLayout(item.inputType);
              return (
                <tr
                  key={`${item.itemCd}-${index}`}
                  className={cn(
                    selectedIndex === index && "bg-sky-50",
                    templateEdit && overCd === item.itemCd && "html-form-drag-over",
                  )}
                  onClick={() => onSelectIndex?.(index)}
                  onDragOver={(e) => {
                    if (!templateEdit) return;
                    e.preventDefault();
                    e.dataTransfer.dropEffect = "move";
                    if (overCd !== item.itemCd) setOverCd(item.itemCd);
                  }}
                  onDragLeave={() => {
                    if (overCd === item.itemCd) setOverCd(null);
                  }}
                  onDrop={(e) => {
                    if (!templateEdit) return;
                    e.preventDefault();
                    setOverCd(null);
                    const from = dragCd.current;
                    dragCd.current = null;
                    if (!from || !onItemsChange) return;
                    onItemsChange(moveHtmlFormBody(items, from, item.itemCd));
                  }}
                >
                  {cycleSpans[index] > 0 ? (
                    <td
                      // 주기 병합 — 조회만. 저장은 행마다 cycleNm. 배경은 헤더와 같은 파랑
                      rowSpan={cycleSpans[index]}
                      className="text-center html-form-pre html-form-axis html-form-cycle-col"
                    >
                      {templateEdit ? (
                        <textarea
                          // 주기 — 같은 값이면 저장 후 병합. 개행은 표준과 같이 유지
                          className="html-form-cell-ta html-form-pre"
                          cols={1}
                          rows={2}
                          value={item.cycleNm}
                          onChange={(e) => patchItem(item.itemCd, { cycleNm: e.target.value })}
                        />
                      ) : (
                        item.cycleNm
                      )}
                    </td>
                  ) : null}
                  {grpSpans[index] > 0 ? (
                    <td
                      // 관리 병합 — 배경은 헤더와 같은 파랑
                      rowSpan={grpSpans[index]}
                      className="text-center html-form-pre html-form-axis html-form-grp-col"
                    >
                      {templateEdit ? (
                        <textarea
                          // 관리(구분) — 같은 값이면 저장 후 병합
                          className="html-form-cell-ta html-form-pre"
                          cols={1}
                          rows={2}
                          value={item.grpNm}
                          onChange={(e) => patchItem(item.itemCd, { grpNm: e.target.value })}
                        />
                      ) : (
                        item.grpNm
                      )}
                    </td>
                  ) : null}
                  <td className="html-form-pre html-form-item-col">
                    {templateEdit ? (
                      <textarea
                        // 점검내용 — Enter = U+000A. 남는 폭을 이 칸이 쓴다
                        className="html-form-cell-ta html-form-pre"
                        cols={1}
                        rows={2}
                        value={item.itemNm}
                        onChange={(e) => patchItem(item.itemCd, { itemNm: e.target.value })}
                      />
                    ) : (
                      item.itemNm
                    )}
                  </td>
                  {templateEdit ? (
                    <>
                      <td className="html-form-type-col">
                        <select
                          // 입력유형 — 전용 열. 값 칸에 두면 유형 변경 시 셀이 깨진다
                          className="html-form-type"
                          value={normalizeHtmlInputTy(item.inputType)}
                          onChange={(e) => {
                            const next = normalizeHtmlInputTy(e.target.value);
                            patchItem(item.itemCd, {
                              inputType: next,
                              unitNm: htmlFormInputLayout(next).num ? (item.unitNm || HTML_INPUT_DEFAULT_UNIT) : "",
                            });
                          }}
                        >
                          {typeOptions.map((opt) => (
                            <option key={opt.subCd} value={opt.subCd}>{opt.codeNm}</option>
                          ))}
                        </select>
                      </td>
                      <td className="html-form-row-col html-form-no-print">
                        <div
                          // 순서 손잡이 + 삭제 — 인쇄 숨김
                          className="html-form-row-tools"
                        >
                          <MesButton
                            // 사용자 버전 행 삭제 — 그리드 삭제와 같은 아이콘
                            size="sm"
                            variant="danger"
                            icon="trash"
                            onClick={(event) => {
                              event.stopPropagation();
                              removeRow(item.itemCd);
                            }}
                          >
                            삭제
                          </MesButton>
                          <button
                            // 행 순서 — sort_no. 삭제 오른쪽. 칸 입력을 끌어가지 않게 손잡이만
                            type="button"
                            className="html-form-drag"
                            draggable
                            aria-label="행 순서 이동"
                            onClick={(event) => event.stopPropagation()}
                            onDragStart={(e) => {
                              dragCd.current = item.itemCd;
                              e.dataTransfer.effectAllowed = "move";
                              e.dataTransfer.setData("text/plain", item.itemCd);
                            }}
                            onDragEnd={() => {
                              dragCd.current = null;
                              setOverCd(null);
                            }}
                          >
                            <GripVertical
                              // 드래그 손잡이
                              className="h-3.5 w-3.5"
                              aria-hidden
                            />
                          </button>
                        </div>
                      </td>
                    </>
                  ) : (
                    <>
                      <td className="text-center html-form-yn-col">
                        {radio ? (
                          <input
                            // 예 — 문구는 공통코드 judge-yn
                            type="radio"
                            name={`yn-${index}`}
                            checked={item.yn === "Y"}
                            disabled={!writeEdit}
                            onChange={() => patchItem(item.itemCd, { yn: "Y" })}
                          />
                        ) : null}
                      </td>
                      <td className="text-center html-form-yn-col">
                        {radio ? (
                          <input
                            // 아니오 — 문구는 공통코드 judge-yn
                            type="radio"
                            name={`yn-${index}`}
                            checked={item.yn === "N"}
                            disabled={!writeEdit}
                            onChange={() => patchItem(item.itemCd, { yn: "N" })}
                          />
                        ) : null}
                      </td>
                      <td className={cn("html-form-val-col", valueCell && "html-form-temp")}>
                        {valueCell ? (
                          <input
                            // 숫자·문자 값. 값 칸이 있으면 빨간 테두리. 라디오 전용은 빈 칸
                            className="w-full border-0 bg-transparent px-0.5 html-form-pre"
                            value={item.valNm ?? ""}
                            disabled={!writeEdit}
                            onChange={(e) => patchItem(item.itemCd, { valNm: e.target.value })}
                          />
                        ) : null}
                      </td>
                    </>
                  )}
                </tr>
              );
            })
          )}
        </tbody>
      </table>
      <HtmlFormRowAddSlot
        // 본문과 풋터 사이 — 캡션과 같은 높이의 문구 칸
        items={items}
        templateEdit={templateEdit}
        onItemsChange={onItemsChange}
      >
        {templateEdit ? (
          <MesButton
            // 표 오른쪽 끝 행 추가 — 바로 위 행의 주기·관리·유형을 이어 받는다
            size="sm"
            variant="add"
            icon="plus"
            onClick={addRow}
          >
            행추가
          </MesButton>
        ) : null}
      </HtmlFormRowAddSlot>
      <HtmlFormFootTable
        // 특이사항·조치·확인 — 공정·검증이 같은 행 높이
        header={header}
        footer={footer}
        writeEdit={writeEdit}
        noteLabel="특이사항"
        actionLabel="조치"
        onFooterChange={onFooterChange}
      />
    </article>
  );
}
