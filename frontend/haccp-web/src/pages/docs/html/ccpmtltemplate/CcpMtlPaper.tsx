/**
 * CcpMtlPaper — 중요관리점(CCP-3P) 모니터링일지 [금속검출공정] 지면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 기준관리 미리보기는 원본 일지 레이아웃. 한계기준은 금속이물 값만. 주기·방법·감도열·개선조치를 수정한다
 *   2) 미리보기는 작업 전·빈행·작업 후·빈행 4행. 해당 없음은 작업 전·후 행. 중간 행은 작성에서 넣는다
 *   3) 판정은 적합/부적합 반 가름 라디오. 기록 행 품명은 흰색
 *
 * PIPELINE[HF134] CCP-3P 금속검출일지 지면
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

/** 시드 item_cd — tbl_check_item tml_ccp_mtl_000 */
export const MTL_ITEM = {
  LIMIT_METAL: "limit-metal",
  CYCLE: "cycle",
  METHOD: "method",
  CORRECTIVE: "corrective",
} as const;

/** 감도 열 — unitNm=Y 이면 고정행에 해당 없음 */
export const MTL_HDR = [
  { cd: "hdr-fe", fallback: "Fe만 통과", defaultNa: false },
  { cd: "hdr-sus", fallback: "SUS만 통과", defaultNa: false },
  { cd: "hdr-prod", fallback: "제품만 통과", defaultNa: true },
  { cd: "hdr-fe-prod", fallback: "Fe+제품 통과", defaultNa: true },
  { cd: "hdr-sus-prod", fallback: "SUS+제품 통과", defaultNa: true },
] as const;

const PASS_CNT = 4;

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) A4 표 한 장. 제목·결재와 본문을 나눈다
 *   2) 기준관리·작성 화면이 같은 컴포넌트를 쓴다
 *   3) 저장 API는 호출하지 않는다
 */
export function CcpMtlPaper({
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
  // 한계기준·주기·방법·감도열·개선조치
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
  // 작성만 중간 행. 미리보기는 작업 전·빈행·작업 후·빈행 4행
  const [midKeys, setMidKeys] = useState<string[]>([]);

  // 항목 패치 — 한계기준·주기·방법·개선조치·감도열
  const patchItem = (cd: string, patch: Partial<HtmlFormItem>) => {
    patchHtmlFormItem(items, cd, patch, onItemsChange);
  };

  const hdrs = MTL_HDR.map((col) => {
    const row = htmlFormItemOf(items, col.cd);
    const na = (row?.unitNm ?? (col.defaultNa ? "Y" : "N")) === "Y";
    return { cd: col.cd, label: row?.itemNm || col.fallback, na };
  });

  const limitMetal = htmlFormItemNm(items, MTL_ITEM.LIMIT_METAL);
  const cycleNm = htmlFormItemNm(items, MTL_ITEM.CYCLE);
  const methodNm = htmlFormItemNm(items, MTL_ITEM.METHOD);
  const correctiveNm = htmlFormItemNm(items, MTL_ITEM.CORRECTIVE);

  return (
    <article
      // A4 또는 패널 채움
      className={variant === "fill" ? "doc-paper-fill" : "doc-paper-a4"}
      aria-label="중요관리점(CCP-3P) 모니터링일지"
    >
      <HtmlFormBanner
        // 제목·결재·작성일자·점검자. 포장·가열과 같은 표
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
        // 한계기준 1행 + 주기 + 방법. 값만 텍스트
        limitRows={[{ cd: MTL_ITEM.LIMIT_METAL, itemNm: limitMetal }]}
        cycle={{ cd: MTL_ITEM.CYCLE, itemNm: cycleNm }}
        method={{ cd: MTL_ITEM.METHOD, itemNm: methodNm }}
        templateEdit={templateEdit}
        onPatch={(nms) => patchHtmlFormItemNms(items, nms, onItemsChange)}
      />

      <table
        // 감도 기록 표 — 행 높이는 ccp-log-body
        className="html-form-table html-form-body ccp-log-body"
      >
        <CcpLogCaption
          // 감도 표 제목 — 시드 문구. 수정 때 입력
          items={items}
          fallback="금속검출기 감도 모니터링 (검출 = O, 불검출 = X)"
          templateEdit={templateEdit}
          onItemsChange={onItemsChange}
        />
        <colgroup>
          <col className="ccp-mtl-prod" />
          <col className="ccp-mtl-time" />
          {hdrs.map((col) => (
            <col
              // 감도 열 폭
              key={col.cd}
              className="ccp-mtl-ox"
            />
          ))}
          <col className="ccp-pf-yn" />
          <col className="ccp-pf-yn" />
          <col className="ccp-mtl-sign" />
        </colgroup>
        <thead>
          <tr>
            <th rowSpan={2}>품명</th>
            <th rowSpan={2}>통과시간</th>
            {hdrs.map((col) => (
              <th
                // 감도열 — 통과시간과 같이 2행 병합. 판정처럼 아래 칸을 나누지 않는다
                key={col.cd}
                rowSpan={2}
              >
                {templateEdit ? (
                  <input
                    // 감도 열 헤더 — 자사 양식만. cell-ta 를 쓰면 헤더가 찌그러진다
                    className="ccp-mtl-hdr-input"
                    value={col.label}
                    onChange={(e) => patchItem(col.cd, { itemNm: e.target.value })}
                  />
                ) : (
                  col.label
                )}
              </th>
            ))}
            <th
              // 판정 — 적합/부적합 위 병합
              colSpan={2}
            >
              판정
            </th>
            <th rowSpan={2}>서명</th>
          </tr>
          <tr>
            <th className="ccp-pf-yn">{passNm}</th>
            <th className="ccp-pf-yn">{failNm}</th>
          </tr>
        </thead>
        <tbody>
          <SensRow
            // 작업 전 — 해당 없음 체크는 이 행. 아래에 빈 예시 행
            rowKey="mtl-before"
            label="작업 전"
            fixed
            hdrs={hdrs}
            templateEdit={templateEdit}
            writeEdit={writeEdit}
            onNaChange={(cd, na) => patchItem(cd, { unitNm: na ? "Y" : "N" })}
          />
          <SensRow
            // 작업 전 아래 빈 행 — 미리보기 예시. 해당 없음과 무관
            rowKey="mtl-before-empty"
            hdrs={hdrs}
            templateEdit={templateEdit}
            writeEdit={writeEdit}
          />
          {writeEdit ? midKeys.map((key) => (
            <SensRow
              // 작성 중간 행 — 품명 입력. 해당 없음과 무관, O/X
              key={key}
              rowKey={key}
              hdrs={hdrs}
              templateEdit={templateEdit}
              writeEdit={writeEdit}
            />
          )) : null}
          <SensRow
            // 작업 후 — 해당 없음 체크는 이 행
            rowKey="mtl-after"
            label="작업 후"
            fixed
            hdrs={hdrs}
            templateEdit={templateEdit}
            writeEdit={writeEdit}
            onNaChange={(cd, na) => patchItem(cd, { unitNm: na ? "Y" : "N" })}
          />
          <SensRow
            // 작업 후 아래 빈 행 — 미리보기 예시
            rowKey="mtl-after-empty"
            hdrs={hdrs}
            templateEdit={templateEdit}
            writeEdit={writeEdit}
          />
        </tbody>
      </table>
      <HtmlFormRowAddSlot
        // 감도 표와 통과량 표 사이 — 통과량 제목을 여기 둔다. 표 caption 은 쓰지 않는다
        items={items}
        // 자사 수정 중이면 글자 입력
        templateEdit={templateEdit}
        // 시드가 없을 때 통과량 표 제목
        fallback="금속검출기 제품 통과"
        // 수정한 제목을 hdr-gap-cap 으로 붙인다
        onItemsChange={onItemsChange}
      >
        {writeEdit ? (
          <MesButton
            // 작업 전과 후 사이에 품명 행을 끼운다
            size="sm"
            variant="add"
            icon="plus"
            onClick={() => setMidKeys((keys) => [...keys, `mtl-mid-${Date.now()}`])}
          >
            행 추가
          </MesButton>
        ) : null}
      </HtmlFormRowAddSlot>

      <table
        // 통과량 표 — 제목은 위 간격 칸. 기록 표와 같은 행 높이
        className="html-form-table html-form-body ccp-log-body"
      >
        <thead>
          <tr>
            <th>품명</th>
            <th>통과량</th>
            <th>검출량</th>
            <th>특이사항</th>
          </tr>
        </thead>
        <tbody>
          {Array.from({ length: PASS_CNT }, (_, i) => (
            <tr key={`pass-${i}`}>
              <td>
                <input
                  // 품명 — 문자
                  className="html-form-sign-input"
                  disabled={!writeEdit}
                  readOnly={!writeEdit}
                />
              </td>
              <td>
                <input
                  // 통과량
                  className="html-form-sign-input"
                  disabled={!writeEdit}
                  readOnly={!writeEdit}
                />
              </td>
              <td>
                <input
                  // 검출량
                  className="html-form-sign-input"
                  disabled={!writeEdit}
                  readOnly={!writeEdit}
                />
              </td>
              <td>
                <input
                  // 특이사항
                  className="html-form-sign-input"
                  disabled={!writeEdit}
                  readOnly={!writeEdit}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <CcpCorrectiveBlock
        // 개선조치 방법 — 포장·가열과 같은 칸 높이
        value={correctiveNm}
        templateEdit={templateEdit}
        onChange={(next) => patchItem(MTL_ITEM.CORRECTIVE, { itemNm: next })}
      />
      <HtmlFormFootTable
        // 이탈·조치·확인 — 포장·가열과 같은 행 높이
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

type HdrCol = { cd: string; label: string; na: boolean };

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 감도 표 한 행. 미리보기는 작업 전·빈행·작업 후·빈행
 *   2) 해당 없음 체크는 작업 전·후만. 헤더에는 두지 않는다
 *   3) 판정은 적합/부적합 칸 라디오. 기록 행 품명은 흰색
 */
function SensRow({
  // 라디오 name — 행마다 다르게
  rowKey,
  // 품명 고정 라벨. 없으면 빈칸
  label,
  // 고정행이면 해당 없음 적용
  fixed = false,
  hdrs,
  // 기준관리 수정 — 작업 전·후 칸에 체크
  templateEdit,
  writeEdit,
  // 열 단위 해당 없음
  onNaChange,
}: {
  rowKey: string;
  label?: string;
  fixed?: boolean;
  hdrs: HdrCol[];
  templateEdit: boolean;
  writeEdit: boolean;
  onNaChange?: (cd: string, na: boolean) => void;
}) {
  return (
    <tr>
      <td>
        {label ? label : (
          <input
            // 빈 행·작성 중간 품명 — 문자. 해당 없음과 무관
            className="html-form-sign-input"
            disabled={!writeEdit}
            readOnly={!writeEdit}
          />
        )}
      </td>
      <td>
        <input
          // 통과시간 — 미리보기는 빈칸. 콜론 자리표시 없음
          className="html-form-sign-input"
          disabled={!writeEdit}
          readOnly={!writeEdit}
        />
      </td>
      {hdrs.map((col) => (
        <td key={col.cd}>
          {fixed && templateEdit ? (
            <label
              // 작업 전·후 해당 없음 — 열 단위. 헤더에 두면 전 행처럼 보인다
              className="ccp-mtl-na-cell"
            >
              <input
                type="checkbox"
                checked={col.na}
                onChange={(e) => onNaChange?.(col.cd, e.target.checked)}
              />
              해당 없음
            </label>
          ) : fixed && col.na ? (
            <span
              // 조회·작성 고정행 — 해당 없음 문구
              className="ccp-mtl-na"
            >
              해당 없음
            </span>
          ) : writeEdit ? (
            <span className="ccp-pkg-num-wrap">
              <label className="ccp-pkg-judge-opt">
                <input
                  // 검출 O
                  type="radio"
                  name={`mtl-ox-${rowKey}-${col.cd}`}
                  disabled={!writeEdit}
                />
                O
              </label>
              <label className="ccp-pkg-judge-opt">
                <input
                  // 불검출 X
                  type="radio"
                  name={`mtl-ox-${rowKey}-${col.cd}`}
                  disabled={!writeEdit}
                />
                X
              </label>
            </span>
          ) : null}
        </td>
      ))}
      <td className="text-center ccp-pf-yn">
        <input
          // 적합 — 헤더 문구. 칸에는 라디오만
          type="radio"
          name={`mtl-pf-${rowKey}`}
          disabled={!writeEdit}
        />
      </td>
      <td className="text-center ccp-pf-yn">
        <input
          // 부적합
          type="radio"
          name={`mtl-pf-${rowKey}`}
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
