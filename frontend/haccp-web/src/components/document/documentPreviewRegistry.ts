/**
 * documentPreviewRegistry — 양식코드 → 결재 미리보기 렌더러 매핑.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 결재 화면(sign-ready·sign-ok)이 문서 종류를 몰라도 되도록 tmpl_cd 접두 하나로 지면·API 를 고른다
 *   2) ApprovalDocumentPreview 가 HTML 문서일 때 호출한다. HWP 는 이 표를 타지 않는다(rhwp 단일 경로)
 *   3) 새 HTML 양식군이 생기면 여기 한 줄만 넣는다 — 미리보기 컴포넌트는 고치지 않는다
 *
 * 접두·지면·API 는 각 작성 화면 Rule/api 가 이미 갖고 있는 값을 그대로 가져온다. 새 상수를 만들지 않는다.
 * 화면 이동 매핑(`lib/documentNav.ts`)과 접두 문자열이 같아야 한다 — 한쪽만 늘리면 갈린다.
 *
 * PIPELINE[HF184] 결재 문서 미리보기
 * PIPELINE[HF82, HF172] 연관 모듈
 */
// 역할 — 지면 공통 props 타입
import type { ComponentType } from "react";
import type { HtmlFormPaperProps } from "@/components/form/htmlFormPaperShared";
// 역할 — 화면별 작성 API 계약 (상세 조회에 쓴다)
import type { HtmlFormDraftApi } from "@/api/draft/htmlFormDraftTypes";
// 역할 — 화면별 작성 API 구현
import { hygProcessDraftApi } from "@/api/draft/hygProcessDraftApi";
import { ccpVerifyDraftApi } from "@/api/draft/ccpVerifyDraftApi";
import {
  ccpHtgDraftApi,
  ccpMtlDraftApi,
  ccpPkgDraftApi,
} from "@/api/draft/ccpMonitoringDraftApi";
// 역할 — 화면별 지면
import { HygPrcPaper } from "@/pages/docs/html-form/htmltemplate/HygPrcPaper";
import { CcpChkPaper } from "@/pages/docs/html-form/ccpverifytemplate/CcpChkPaper";
import { CcpPkgPaper } from "@/pages/docs/html-form/ccppkgtemplate/CcpPkgPaper";
import { CcpHtgPaper } from "@/pages/docs/html-form/ccphtgtemplate/CcpHtgPaper";
import { CcpMtlPaper } from "@/pages/docs/html-form/ccpmtltemplate/CcpMtlPaper";
// 역할 — 화면별 접두·지면 제목 (작성 화면 Rule 정본)
import * as HygRule from "@/pages/draft/html/HygProcessDraftRule";
import * as CcpChkRule from "@/pages/draft/html/CcpVerifyDraftRule";
import * as CcpPkgRule from "@/pages/draft/ccp-monitoring/CcpPkgDraftRule";
import * as CcpHtgRule from "@/pages/draft/ccp-monitoring/CcpHtgDraftRule";
import * as CcpMtlRule from "@/pages/draft/ccp-monitoring/CcpMtlDraftRule";

/** 미리보기 한 종류 — 어느 지면을 어느 API 로 채울지 */
export interface DocumentPreviewEntry {
  // 자사 양식코드 접두 — 뒤 3자리는 회사마다 다르다
  prefix: string;
  // 작성 화면코드 — 「작성화면 열기」 이동에 쓴다
  scrnCd: string;
  // 읽기전용으로 그릴 지면
  Paper: ComponentType<HtmlFormPaperProps>;
  // 상세(header·items·기록행)를 주는 작성 API
  api: HtmlFormDraftApi;
  // 양식명이 비었을 때 쓸 지면 제목
  paperTitle: string;
  // 지면 부제
  paperSubtitle: string;
}

/** HTML 양식군 5종 — 작성 화면과 1:1 */
const ENTRIES: readonly DocumentPreviewEntry[] = [
  {
    prefix: HygRule.USR_TMPL_PREFIX,
    scrnCd: HygRule.SCRN_CD,
    Paper: HygPrcPaper,
    api: hygProcessDraftApi,
    paperTitle: HygRule.PAPER_TITLE,
    paperSubtitle: HygRule.PAPER_SUBTITLE,
  },
  {
    prefix: CcpChkRule.USR_TMPL_PREFIX,
    scrnCd: CcpChkRule.SCRN_CD,
    Paper: CcpChkPaper,
    api: ccpVerifyDraftApi,
    paperTitle: CcpChkRule.PAPER_TITLE,
    paperSubtitle: CcpChkRule.PAPER_SUBTITLE,
  },
  {
    prefix: CcpPkgRule.USR_TMPL_PREFIX,
    scrnCd: CcpPkgRule.SCRN_CD,
    Paper: CcpPkgPaper,
    api: ccpPkgDraftApi,
    paperTitle: CcpPkgRule.PAPER_TITLE,
    paperSubtitle: CcpPkgRule.PAPER_SUBTITLE,
  },
  {
    prefix: CcpHtgRule.USR_TMPL_PREFIX,
    scrnCd: CcpHtgRule.SCRN_CD,
    Paper: CcpHtgPaper,
    api: ccpHtgDraftApi,
    paperTitle: CcpHtgRule.PAPER_TITLE,
    paperSubtitle: CcpHtgRule.PAPER_SUBTITLE,
  },
  {
    prefix: CcpMtlRule.USR_TMPL_PREFIX,
    scrnCd: CcpMtlRule.SCRN_CD,
    Paper: CcpMtlPaper,
    api: ccpMtlDraftApi,
    paperTitle: CcpMtlRule.PAPER_TITLE,
    paperSubtitle: CcpMtlRule.PAPER_SUBTITLE,
  },
];

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 양식코드 접두로 미리보기 렌더러를 찾는다
 *   2) HtmlDocumentPreview 가 문서를 열 때 한 번 호출한다
 *   3) 예시 양식(_000)과 매핑 없는 구양식(html_sys_*)은 undefined — 호출측이 안내 문구로 대체한다
 */
export function previewEntryOf(
  // 문서 양식코드 — tbl_document.tmpl_cd
  tmplCd: string
): DocumentPreviewEntry | undefined {
  const cd = (tmplCd || "").trim();
  // 예시 000 일 때(= 작성 대상이 아닌 기준관리 예시) 미리보기 대상에서 뺀다
  if (cd.endsWith("_000")) return undefined;
  return ENTRIES.find((entry) => cd.startsWith(entry.prefix));
}
