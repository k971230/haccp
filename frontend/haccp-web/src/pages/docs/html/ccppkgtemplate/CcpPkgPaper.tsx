/**
 * CcpPkgPaper — 중요관리점(CCP-1B) 모니터링일지 [포장공정] 지면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 기준관리 미리보기는 원본 일지 레이아웃. 한계기준·주기·방법·개선조치는 텍스트
 *   2) 미리보기는 작업 전·빈행·작업 종료·빈행 4행. 측정시각·온도는 비운다. 중간 행은 작성에서 넣는다
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
  SignSlot,
  htmlFormItemNm,
  htmlFormItemOf,
  htmlFormPaperEdit,
  patchHtmlFormItem,
  patchHtmlFormItemNms,
  useJudgePfLabels,
  type HtmlFormPaperProps,
} from "@/components/form/htmlFormPaperShared";
// 역할 — 항목 패치
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";
// 역할 — 작성 화면 중간 행 추가
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 작성 중간 행 키
import { useState } from "react";

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
  onHeaderChange,
  onItemsChange,
  onFooterChange,
}: HtmlFormPaperProps) {
  // 적합/부적합 헤더 — 공통코드 JUDGE_PF
  const { passNm, failNm } = useJudgePfLabels();
  const { templateEdit, writeEdit } = htmlFormPaperEdit(mode, locked, editable, editing);
  // 작성만 중간 행. 미리보기는 작업 전·빈행·작업 종료·빈행 4행
  const [midKeys, setMidKeys] = useState<string[]>([]);

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
          {writeEdit ? midKeys.map((key) => (
            <LogPreviewRow
              // 작성 중간 행 — 품명 입력
              key={key}
              rowKey={key}
              writeEdit={writeEdit}
            />
          )) : null}
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
        </tbody>
      </table>
      <HtmlFormRowAddSlot
        // 기록 표와 개선조치 사이 — 캡션과 같은 높이의 문구 칸
        items={items}
        templateEdit={templateEdit}
        onItemsChange={onItemsChange}
      >
        {writeEdit ? (
          <MesButton
            // 작업 전과 종료 사이에 품명 행을 끼운다
            size="sm"
            variant="add"
            icon="plus"
            onClick={() => setMidKeys((keys) => [...keys, `pkg-mid-${Date.now()}`])}
          >
            행 추가
          </MesButton>
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
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 기록 표 한 행. 미리보기는 작업 전·빈행·작업 종료·빈행. 시각·온도는 빈칸
 *   2) 품명은 고정 라벨. 판정은 적합/부적합 칸 라디오
 *   3) 온도·분·초는 type=number
 */
function LogPreviewRow({
  // 라디오 name — 행마다 다르게
  rowKey,
  // 품명 고정값 — 작업 전 / 작업 종료
  label,
  // 작성 편집
  writeEdit,
}: {
  rowKey: string;
  label?: string;
  writeEdit: boolean;
}) {
  return (
    <tr>
      <td>
        {label ? label : (
          <input
            // 작성 중간 품명 — 문자. 작업 전·종료는 고정 라벨
            className="html-form-sign-input"
            disabled={!writeEdit}
            readOnly={!writeEdit}
          />
        )}
      </td>
      <td>
        <input
          // 측정시각 — 작성만. 미리보기는 빈칸
          className="html-form-sign-input"
          disabled={!writeEdit}
          readOnly={!writeEdit}
        />
      </td>
      <td>
        <span className="ccp-pkg-num-wrap">
          <input
            // 작업장 온도 — 숫자만. 미리보기는 빈칸
            className="html-form-sign-input ccp-pkg-num"
            type="number"
            inputMode="decimal"
            step="0.1"
            disabled={!writeEdit}
            readOnly={!writeEdit}
          />
          <span>℃</span>
        </span>
      </td>
      <td>
        <input
          // 포장 소진시간 분 — 숫자만
          className="html-form-sign-input ccp-pkg-num"
          type="number"
          inputMode="numeric"
          min={0}
          disabled={!writeEdit}
          readOnly={!writeEdit}
        />
      </td>
      <td>
        <input
          // 포장 소진시간 초 — 숫자만
          className="html-form-sign-input ccp-pkg-num"
          type="number"
          inputMode="numeric"
          min={0}
          disabled={!writeEdit}
          readOnly={!writeEdit}
        />
      </td>
      <td className="text-center ccp-pf-yn">
        <input
          // 적합 — 헤더 문구. 칸에는 라디오만
          type="radio"
          name={`pkg-pf-${rowKey}`}
          disabled={!writeEdit}
        />
      </td>
      <td className="text-center ccp-pf-yn">
        <input
          // 부적합
          type="radio"
          name={`pkg-pf-${rowKey}`}
          disabled={!writeEdit}
        />
      </td>
      <td>
        <SignSlot
          // 행 서명 — 이미지 또는 이름. 미리보기는 빈칸
          name=""
          editable={writeEdit}
        />
      </td>
    </tr>
  );
}
