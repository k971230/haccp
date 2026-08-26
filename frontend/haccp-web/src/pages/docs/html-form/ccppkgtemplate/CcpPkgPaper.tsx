/**
 * CcpPkgPaper — 중요관리점(CCP-1B) 모니터링일지 [포장공정] 지면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 기준관리 미리보기는 원본 일지 레이아웃. 한계기준·주기·방법·개선조치는 텍스트
 *   2) mode=template 은 예전 그대로 미리보기 4행 고정(입력 불가·행추가 없음). 기준관리 동작을 바꾸지 않는다
 *      mode=write 는 logRows 를 제어 렌더한다 — 작업 전/작업 종료를 phaseCd 로 갈라 행 추가·삭제·저장
 *   3) 판정은 적합/부적합 반 가름 라디오. 기록 행 품명은 흰색
 *
 * PIPELINE[HF132] CCP-1B 포장일지 지면
 */
// 역할 — 공통 지면 props · 결재 서명 슬롯
import {
  CcpCorrectiveBlock,
  CcpLimitHeaderTable,
  CcpLogCaption,
  HtmlFormBanner,
  HtmlFormFootTable,
  HtmlFormRowAddSlot,
  LOG_PHASE,
  SignSlot,
  appendLogRow,
  logRowsOf,
  patchLogRow,
  removeLogRow,
  CELL_KIND,
  HtmlFormCellInput,
  htmlFormItemNm,
  htmlFormItemOf,
  htmlFormPaperEdit,
  patchHtmlFormItem,
  patchHtmlFormItemNms,
  useJudgePfLabels,
  type HtmlFormLogRow,
  type HtmlFormPaperProps,
  type LogPhase,
} from "@/components/form/htmlFormPaperShared";
// 역할 — 항목 패치
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";
// 역할 — 영역별 행 추가·행 삭제 버튼
import { MesButton } from "@/components/ui/MesButton";

/** 시드 item_cd — tbl_check_item tml_ccp_pkg_000 */
export const PKG_ITEM = {
  LIMIT_TEMP: "limit-temp",
  LIMIT_TIME: "limit-time",
  CYCLE: "cycle",
  METHOD: "method",
  CORRECTIVE: "corrective",
} as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) A4 표 한 장. 제목·결재와 본문을 나눠 한계기준 폭이 제목을 먹지 않게 한다
 *   2) 기준관리·작성 화면이 같은 컴포넌트를 쓴다
 *   3) 저장 API는 호출하지 않는다
 */
export function CcpPkgPaper({
  // 기준관리 / 작성
  mode,
  // 표준 잠금
  locked,
  // 셀 편집 가능
  editable,
  // 기준관리 수정 버튼 이후
  editing = false,
  // 용지 폭
  variant = "a4",
  // 상단 제목·일자·점검자·결재
  header,
  // 한계기준·주기·방법·개선조치 5항목
  items,
  // 하단 이탈·조치
  footer,
  // 작성 기록 행 — 없으면(= 기준관리) 예전처럼 빈 예시 행을 고정으로 그린다
  logRows,
  onHeaderChange,
  onItemsChange,
  onFooterChange,
  onLogRowsChange,
}: HtmlFormPaperProps) {
  // 적합/부적합 헤더 — 공통코드 JUDGE_PF
  const { passNm, failNm } = useJudgePfLabels();
  const { templateEdit, writeEdit, writeView } = htmlFormPaperEdit(mode, locked, editable, editing);
  // 작성 제어 렌더 여부 — logRows 를 받은 mode=write 에서만. 기준관리는 항상 false
  // 저장된 기록행이 있으면 그린다 — 잠긴 문서·결재 미리보기도 값이 보여야 한다
  const writeRows = writeView && !!logRows;
  const rows = logRows ?? [];

  // 항목 패치 — 한계기준·주기·방법·개선조치 itemNm
  const patchItem = (cd: string, patch: Partial<HtmlFormItem>) => {
    patchHtmlFormItem(items, cd, patch, onItemsChange);
  };

  // 기록 표 열 제목 — 표시만. 시드는 작업장 온도
  const limitTempKey = htmlFormItemOf(items, PKG_ITEM.LIMIT_TEMP)?.cycleNm || "작업장 온도";
  // 기록 표 열 제목 — 표시만. 시드는 포장 완료 시까지 소진시간
  const limitTimeKey = htmlFormItemOf(items, PKG_ITEM.LIMIT_TIME)?.cycleNm || "포장 완료 시까지 소진시간";
  const limitTemp = htmlFormItemNm(items, PKG_ITEM.LIMIT_TEMP);
  const limitTime = htmlFormItemNm(items, PKG_ITEM.LIMIT_TIME);
  const cycleNm = htmlFormItemNm(items, PKG_ITEM.CYCLE);
  const methodNm = htmlFormItemNm(items, PKG_ITEM.METHOD);
  const correctiveNm = htmlFormItemNm(items, PKG_ITEM.CORRECTIVE);

  return (
    <article
      // A4 또는 패널 채움
      className={variant === "fill" ? "doc-paper-fill" : "doc-paper-a4"}
      aria-label="중요관리점(CCP-1B) 모니터링일지"
    >
      <HtmlFormBanner
        // 제목·결재·작성일자·점검자. 가열·금속과 같은 표
        header={header}
        items={items}
        mode={mode}
        templateEdit={templateEdit}
        writeEdit={writeEdit}
        dateLabel="작성일자"
        onHeaderChange={onHeaderChange}
        onItemsChange={onItemsChange}
      />

      <CcpLimitHeaderTable
        // 한계기준 한 칸 + 주기 + 방법. 온도·시간은 항목명 : 값 두 줄
        limitRows={[
          { cd: PKG_ITEM.LIMIT_TEMP, itemNm: limitTemp, label: limitTempKey },
          { cd: PKG_ITEM.LIMIT_TIME, itemNm: limitTime, label: limitTimeKey },
        ]}
        cycle={{ cd: PKG_ITEM.CYCLE, itemNm: cycleNm }}
        method={{ cd: PKG_ITEM.METHOD, itemNm: methodNm }}
        templateEdit={templateEdit}
        onPatch={(nms) => patchHtmlFormItemNms(items, nms, onItemsChange)}
      />

      <table
        // 기록 표 — 행 높이는 ccp-log-body
        className="html-form-table html-form-body ccp-log-body"
      >
        <CcpLogCaption
          // 포장·가열은 빈칸으로 한계기준과 기록 표를 벌린다
          items={items}
          fallback=""
          templateEdit={templateEdit}
          onItemsChange={onItemsChange}
        />
        <colgroup>
          <col className="ccp-pkg-prod" />
          <col className="ccp-pkg-time" />
          <col className="ccp-pkg-temp" />
          <col className="ccp-pkg-min" />
          <col className="ccp-pkg-sec" />
          <col className="ccp-pf-yn" />
          <col className="ccp-pf-yn" />
          <col className="ccp-pkg-sign" />
        </colgroup>
        <thead>
          <tr>
            <th rowSpan={2}>품명</th>
            <th rowSpan={2}>측정시각</th>
            <th
              // 작업장 온도 열 — 한계기준 항목명과 같다
              rowSpan={2}
            >
              {limitTempKey}
            </th>
            <th
              // 분·초 위 병합. 한계기준 소진시간 항목명과 같다
              colSpan={2}
            >
              {limitTimeKey}
            </th>
            <th
              // 판정 — 적합/부적합 위 병합. 공정점검 기록란과 같다
              colSpan={2}
            >
              판정
            </th>
            <th rowSpan={2}>서명</th>
          </tr>
          <tr>
            <th>분</th>
            <th>초</th>
            <th className="ccp-pf-yn">{passNm}</th>
            <th className="ccp-pf-yn">{failNm}</th>
          </tr>
        </thead>
        <tbody>
          {writeRows ? (
            // 작성 — 저장된 기록행을 영역별로 그린다. 영역 첫 줄만 라벨을 달고 나머지는 품명 입력
            (["BEFORE", "AFTER"] as LogPhase[]).flatMap((phase) =>
              logRowsOf(rows, phase).map((row, idx) => (
                <LogPreviewRow
                  key={`pkg-${phase}-${row.rowSeq}`}
                  rowKey={`pkg-${phase}-${row.rowSeq}`}
                  label={idx === 0 ? (phase === "BEFORE" ? "작업 전" : "작업 종료") : undefined}
                  writeEdit={writeEdit}
                  row={row}
                  // 작성 때는 첫 줄도 지운다. 표가 통째로 비면 저장 SP 가 막으므로 마지막 한 줄만 남긴다
                  onRemove={rows.length > 1 ? () => onLogRowsChange?.(removeLogRow(rows, row.rowSeq)) : undefined}
                  onPatch={(patch) => onLogRowsChange?.(patchLogRow(rows, row.rowSeq, patch))}
                />
              )))
          ) : (
            <>
              <LogPreviewRow
                // 작업 전 — 칸은 비움. 아래에 빈 예시 행
                rowKey="pkg-before"
                label="작업 전"
                writeEdit={writeEdit}
              />
              <LogPreviewRow
                // 작업 전 아래 빈 행 — 미리보기 예시
                rowKey="pkg-before-empty"
                writeEdit={writeEdit}
              />
              <LogPreviewRow
                // 작업 종료 — 칸은 비움
                rowKey="pkg-after"
                label="작업 종료"
                writeEdit={writeEdit}
              />
              <LogPreviewRow
                // 작업 종료 아래 빈 행 — 미리보기 예시
                rowKey="pkg-after-empty"
                writeEdit={writeEdit}
              />
            </>
          )}
        </tbody>
      </table>
      <HtmlFormRowAddSlot
        // 기록 표와 개선조치 사이 — 캡션과 같은 높이의 문구 칸
        items={items}
        templateEdit={templateEdit}
        onItemsChange={onItemsChange}
      >
        {writeRows ? (
          <>
            <MesButton
              // 작업 전 영역 끝에만 행을 붙인다 — 작업 종료 행 수는 그대로다
              size="sm"
              variant="add"
              icon="plus"
              onClick={() => onLogRowsChange?.(appendLogRow(rows, LOG_PHASE.BEFORE))}
            >
              작업 전 행추가
            </MesButton>
            <MesButton
              // 작업 종료 영역 끝에만 행을 붙인다
              size="sm"
              variant="add"
              icon="plus"
              onClick={() => onLogRowsChange?.(appendLogRow(rows, LOG_PHASE.AFTER))}
            >
              작업 종료 행추가
            </MesButton>
          </>
        ) : null}
      </HtmlFormRowAddSlot>

      <CcpCorrectiveBlock
        // 개선조치 방법 — 가열·금속과 같은 칸 높이
        value={correctiveNm}
        templateEdit={templateEdit}
        onChange={(next) => patchItem(PKG_ITEM.CORRECTIVE, { itemNm: next })}
      />
      <HtmlFormFootTable
        // 이탈·조치·확인 — 가열·금속과 같은 행 높이
        header={header}
        footer={footer}
        writeEdit={writeEdit}
        noteLabel="한계기준 이탈내용"
        actionLabel="조치자"
        onFooterChange={onFooterChange}
      />
    </article>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 기록 표 한 행. row 를 주면(= 작성) 제어 입력, 안 주면(= 기준관리) 예전처럼 빈 미리보기 칸이다
 *   2) 품명은 영역 첫 줄만 고정 라벨(작업 전/작업 종료), 나머지는 입력이다
 *   3) 온도·분·초는 type=number. 판정은 적합/부적합 칸 라디오
 */
function LogPreviewRow({
  // 라디오 name — 행마다 다르게
  rowKey,
  // 품명 고정값 — 작업 전 / 작업 종료. 없으면 품명 입력
  label,
  // 작성 편집
  writeEdit,
  // 작성 기록 행 — 없으면 미리보기(비제어)
  row,
  // 칸 수정 — 작성만
  onPatch,
  // 행 삭제 — 추가한 행만. 영역 첫 줄은 넘기지 않는다
  onRemove,
}: {
  rowKey: string;
  label?: string;
  writeEdit: boolean;
  row?: HtmlFormLogRow;
  onPatch?: (patch: Partial<Omit<HtmlFormLogRow, "cells">> & { cells?: Record<string, string> }) => void;
  onRemove?: () => void;
}) {
  const cell = (cd: string) => row?.cells?.[cd] ?? "";
  return (
    <tr>
      <td>
        {label ? label : (
          <HtmlFormCellInput
            // 작성 중간 품명 — 문자. 작업 전·종료는 고정 라벨
            kind={CELL_KIND.TEXT}
            title="품명"
            editable={writeEdit}
            value={row ? row?.productNm ?? "" : undefined}
            onChange={row ? (v) => onPatch?.({ productNm: v }) : undefined}
          />
        )}
      </td>
      <td>
        <HtmlFormCellInput
          // 측정시각 — 작성만. 미리보기는 빈칸
          kind={CELL_KIND.TIME}
          title="시각"
          editable={writeEdit}
          value={row ? row?.checkTime ?? "" : undefined}
          onChange={row ? (v) => onPatch?.({ checkTime: v }) : undefined}
        />
      </td>
      <td>
        <span className="ccp-pkg-num-wrap">
          <HtmlFormCellInput
            // 작업장 온도 — 숫자만. 미리보기는 빈칸
            kind={CELL_KIND.NUM}
            title="온도"
            editable={writeEdit}
            value={row ? cell("temp") : undefined}
            onChange={row ? (v) => onPatch?.({ cells: { temp: v } }) : undefined}
          />
          <span>℃</span>
        </span>
      </td>
      <td>
        <HtmlFormCellInput
          // 포장 소진시간 분 — 숫자만
          kind={CELL_KIND.NUM}
          title="분"
          editable={writeEdit}
          value={row ? cell("min") : undefined}
          onChange={row ? (v) => onPatch?.({ cells: { min: v } }) : undefined}
        />
      </td>
      <td>
        <HtmlFormCellInput
          // 포장 소진시간 초 — 숫자만
          kind={CELL_KIND.NUM}
          title="초"
          editable={writeEdit}
          value={row ? cell("sec") : undefined}
          onChange={row ? (v) => onPatch?.({ cells: { sec: v } }) : undefined}
        />
      </td>
      <td className="text-center ccp-pf-yn">
        <input
          // 적합 — 헤더 문구. 칸에는 라디오만
          type="radio"
          name={`pkg-pf-${rowKey}`}
          disabled={!writeEdit}
          {...(row ? { checked: row.judgeCd === "P", onChange: () => onPatch?.({ judgeCd: "P" }) } : {})}
        />
      </td>
      <td className="text-center ccp-pf-yn">
        <input
          // 부적합
          type="radio"
          name={`pkg-pf-${rowKey}`}
          disabled={!writeEdit}
          {...(row ? { checked: row.judgeCd === "F", onChange: () => onPatch?.({ judgeCd: "F" }) } : {})}
        />
      </td>
      <td>
        <span className="flex items-center justify-center gap-1">
          <SignSlot
            // 행 서명 — 이미지 또는 이름. 미리보기는 빈칸
            name={row?.checkerNm ?? ""}
            editable={writeEdit}
            onChange={row ? (v) => onPatch?.({ checkerNm: v }) : undefined}
          />
          {onRemove ? (
            <MesButton
              // 행 추가로 만든 행만 지운다 — 영역 첫 줄은 버튼이 없다
              size="sm"
              variant="ghost"
              title="행 삭제"
              onClick={onRemove}
            >
              ×
            </MesButton>
          ) : null}
        </span>
      </td>
    </tr>
  );
}
