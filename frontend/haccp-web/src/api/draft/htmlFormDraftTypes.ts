/**
 * htmlFormDraftTypes — 양식 작성(draft) 화면 공통 API 계약.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) HYG(hyg-process)·CCP(ccp-verify) 작성 화면이 같은 행·요청 모양을 쓴다. 화면마다 타입을 복제하지 않는다
 *   2) 실제 URL·양식군·테이블은 화면별 api 파일이 정한다. 여기에는 모양만 둔다
 *   3) 전송·전송취소는 이 계약에 없다 — 문서 허브 processDocumentApproval 공용이다
 *
 * PIPELINE[HF172] 양식 작성 API 계약
 */
// 역할 — 지면 항목 타입 (양식관리와 같은 구조)
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";
// 역할 — 이탈·개선조치 푸터 값
import type { DocCorrectiveValue } from "@/components/form/DocDeviationFooter";
// 역할 — 기록 표 행 계약 (CCP 모니터링일지 작성 공용)
import type { HtmlFormLogRow, HtmlFormPassRow } from "@/components/form/htmlFormPaperShared";

/**
 * 문서 첨부 1건 — HWP 작성만 쓴다.
 * 서버(DocumentService.publicFile)가 내려주는 이름 그대로다 — idx 를 fileIdx 로 바꿔 부르지 않는다.
 */
export interface HtmlFormDraftFile {
  // tbl_document_file.idx — 다운로드 API 경로에 그대로 들어간다
  idx: number;
  // 파일 종류 — HWP_SRC 한글 원본 · PDF 완료본 · ATTACH 첨부 · PHOTO 사진
  fileKind: string;
  // 원본 파일명
  fileNm: string;
  // 파일 크기 byte
  fileSize?: number | null;
}

/** 작성 가능 양식 1건 — 양식관리에서 사용여부 예로 둔 자사 양식 */
export interface HtmlFormDraftForm {
  // 양식코드 — html_hyg_prc_NNN / html_ccp_chk_NNN
  tmplCd: string;
  // 양식명
  verNm: string;
  // 회사 양식 버전 순번 — 자사는 1
  verNo: number;
  // 사용여부 — 서버가 Y 만 내린다
  useYn: string;
  // 양식 등록일자 YYYY-MM-DD — 양식 선택 팝업 첫 컬럼
  insDt?: string | null;
}

/** 좌측 작성 목록 1행 */
export interface HtmlFormDraftListRow {
  docIdx: number;
  hdrIdx: number;
  // 양식코드 — 좌측 팝업 버튼
  tmplCd: string;
  // 양식명
  tmplNm: string;
  docNo: string;
  // 일자 YYYYMMDD
  baseDt: string;
  checkerNm?: string | null;
  // 작성자 ID — 전송·전송취소는 작성자만 가능하다(서버가 다시 막는다)
  writerId?: string | null;
  // 작성자명
  writerNm?: string | null;
  // DOC_STATUS 원본 — 화면이 3단계로 묶는다
  status: string;
  rowCnt?: number;
  ngCnt?: number;
    /** 이탈여부 Y/N — HWP 작성 목록만 채워 온다. 미완료 수(ngCnt)와 다른 축이다 */
    deviationYn?: string | null;
    // 제목 — tbl_document.title. 결재 첨부 remark 가 아니다
    title?: string | null;
}

/** 상세 — 헤더 JSON + 점검행 + 이탈 푸터 */
export interface HtmlFormDraftDetail {
  header: Record<string, unknown> | null;
  items: HtmlFormItem[];
  corrective?: DocCorrectiveValue | null;
  /**
   * 기록 표 행 — CCP 포장·가열·금속검출 작성만 쓴다.
   * HYG·CCP검증은 지면이 items 로 그리므로 비어 온다.
   */
  logRows?: HtmlFormLogRow[];
  /** 금속검출 통과량 표 행 — MTL 작성만 쓴다 */
  passRows?: HtmlFormPassRow[];
  /**
   * 문서 첨부 목록 — HWP 작성만 쓴다.
   * rhwp 가 이 중 최신 HWP_SRC 를 열어 본문으로 삼는다.
   */
  files?: HtmlFormDraftFile[];
  /**
   * 문서 스탬프 — 상세 루트 updDt. 저장 때 seenUpdDt 로 되돌린다.
   * 신규면 없다
   */
  updDt?: string | null;
}

/** 상단 검색 6개 중 서버 조건 5개 — 결재 여부는 화면이 거른다 */
export interface HtmlFormDraftListParams {
  // 양식코드 부분검색. 빈값이면 전체
  tmplCd?: string;
  // 양식명 부분검색
  tmplNm?: string;
  // 일자 시작 YYYYMMDD
  fromDt?: string;
  // 일자 종료 YYYYMMDD
  toDt?: string;
  // 작성자 ID 부분검색
  writerId?: string;
  // 작성자명 부분검색
  writerNm?: string;
  // 제목 부분검색 — tbl_document.title
  title?: string;
}

/** 저장 본문 — 전송 전이라 서버는 필수값을 보지 않는다 */
export interface HtmlFormDraftSaveRequest {
  // 작성 양식코드 — 필수
  tmplCd: string;
  // 기존 문서 idx — 신규면 null
  docIdx?: number | null;
  // 일자 YYYYMMDD
  baseDt: string;
  checkerNm?: string;
  // 승인자 — 저장 시 서명 스냅샷
  approverNm?: string;
  verNo?: number;
  items: HtmlFormItem[];
  specialNote?: string;
  improveNote?: string;
  actionNm?: string;
  confirmNm?: string;
  corrective?: DocCorrectiveValue | null;
  /** 이탈여부 Y/N — HTML 시그널·HWP 목록 칸. 서버가 개선조치 행을 만들거나 지운다 */
  deviationYn?: string;
  /** 기록 표 행 — CCP 모니터링일지 작성만 채운다 */
  logRows?: HtmlFormLogRow[];
  /** 금속검출 통과량 표 행 — MTL 작성만 채운다 */
  passRows?: HtmlFormPassRow[];
  // 목록 제목 — tbl_document.title. 빈값이면 서버가 신규는 양식명·수정은 기존값을 쓴다
  title?: string;
  // 상세에서 받은 문서 스탬프 — 수정 저장 때 서버가 대조한다. 신규·빈 값은 통과
  seenUpdDt?: string;
}

/**
 * 화면별 작성 API 묶음 — 공통 화면 HtmlFormDraftPage 가 이 6개만 호출한다.
 * HYG·CCP 가 각자 자기 경로·테이블로 구현하고, 화면은 어느 쪽인지 모른다.
 */
export interface HtmlFormDraftApi {
  // 작성 가능 양식 — 사용여부 예인 자사 양식만
  listForms: () => Promise<HtmlFormDraftForm[]>;
  // 좌측 작성 목록
  list: (params: HtmlFormDraftListParams) => Promise<HtmlFormDraftListRow[]>;
  // 상세 또는 신규 기본행
  detail: (tmplCd: string, docIdx?: number | null) => Promise<HtmlFormDraftDetail>;
  // 저장 — 문서 idx 반환
  save: (body: HtmlFormDraftSaveRequest) => Promise<number>;
  // 삭제 검증 — 확인창 전. tmplCd 는 SP 가 양식으로 문서를 찾는 화면(MTL)만 쓴다
  validateDelete: (keys: { docIdx: number }[], tmplCd?: string) => Promise<void>;
  // 삭제
  remove: (keys: { docIdx: number }[], tmplCd?: string) => Promise<void>;
}
