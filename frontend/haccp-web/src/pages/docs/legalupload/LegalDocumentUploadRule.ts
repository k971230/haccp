/**
 * LegalDocumentUploadRule — 법적서류 좌 유형·우 문서 그리드 규칙·컬럼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·persistId는 이 파일이 갖는다
 *   2) 시스템 유형(sysYn=Y)은 삭제 불가. 코드는 신규만
 *   3) persistId는 기존 값(legal-tmpl-list · legal-doc-list)을 승계한다
 *
 * PIPELINE[HF122] 법적서류 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 편집행 타입
import type { EditableRow } from "@/types/editable";
// 역할 — 문서·양식 목록 타입
import type { DocumentListRow, DocumentTemplateRow } from "@/api/documentApi";

/** 화면코드 — URL·권한·pref */
export const SCRN_CD = "legal-document-upload" as const;

/** 좌측 유형 열 설정 키 */
export const TMPL_PERSIST_ID = "legal-tmpl-list" as const;

/** 우측 문서 열 설정 키 */
export const DOC_PERSIST_ID = "legal-doc-list" as const;

/** 좌측 유형 행 — 목록 + formUrl(다운로드) */
export type TmplRow = DocumentTemplateRow & {
  formUrl?: string | null;
};

/** 등록 문서 편집 행 — 첨부 표시용 fileNm */
export type DocRow = DocumentListRow & {
  fileNm?: string | null;
};

/** 유형 — 코드는 신규만. 템플릿 파일명·구분은 잠금. 시스템 행 삭제 금지 */
export const TMPL_RULES: ScreenGridRules = {
  newOnly: ["tmplCd"],
  alwaysReadonly: ["formFileNm", "sysYn"],
  isRowDeleteLocked: (row) => String(row.sysYn ?? "Y") === "Y",
};

/** 문서 — 문서번호·상태·첨부는 잠금 */
export const DOC_RULES: ScreenGridRules = {
  newOnly: [],
  alwaysReadonly: ["docNo", "status", "fileCnt", "fileNm"],
};

/** 셀 버튼 — Page가 파일 선택을 연다 */
export interface LegalColumnHandlers {
  onPickTmplFile: (row: EditableRow<TmplRow>) => void;
  onPickDocFile: (row: EditableRow<DocRow>) => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 좌측 유형 열. 템플릿 셀 버튼은 권한 있을 때만
 *   2) 구분은 시스템/회사 표시 전용
 *   3) Page가 useMemo로 호출한다
 */
export function buildTmplColumns(
  editable: boolean,
  handlers: Pick<LegalColumnHandlers, "onPickTmplFile">,
): GridColumn<TmplRow>[] {
  return [
    { field: "tmplCd", header: "코드", width: 120, editable, required: true },
    { field: "tmplNm", header: "유형명", width: 160, editable, required: true },
    {
      field: "formFileNm",
      header: "템플릿",
      width: 160,
      editable: false,
      cellButton: editable
        ? {
          title: "템플릿 선택",
          onClick: (row) => handlers.onPickTmplFile(row as EditableRow<TmplRow>),
          showOnNew: true,
        }
        : undefined,
    },
    {
      field: "sysYn",
      header: "구분",
      width: 80,
      editable: false,
      type: "code",
      codeOptions: [
        { value: "Y", label: "시스템" },
        { value: "N", label: "회사" },
      ],
      codeMap: { Y: "시스템", N: "회사" },
    },
  ];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 우측 등록 문서 열
 *   2) 첨부 셀 버튼은 권한 있을 때만
 *   3) Page가 useMemo로 호출한다
 */
export function buildDocColumns(
  editable: boolean,
  handlers: Pick<LegalColumnHandlers, "onPickDocFile">,
): GridColumn<DocRow>[] {
  return [
    { field: "baseDt", header: "기준일", width: 100, editable, required: true },
    { field: "docNo", header: "문서번호", width: 140, editable: false },
    { field: "title", header: "제목", width: 160, editable },
    {
      field: "fileNm",
      header: "첨부파일",
      width: 180,
      editable: false,
      cellButton: editable
        ? {
          title: "파일 선택",
          onClick: (row) => handlers.onPickDocFile(row as EditableRow<DocRow>),
          showOnNew: true,
        }
        : undefined,
    },
    { field: "status", header: "상태", width: 80, editable: false },
    { field: "fileCnt", header: "첨부", width: 70, type: "number", editable: false },
  ];
}
