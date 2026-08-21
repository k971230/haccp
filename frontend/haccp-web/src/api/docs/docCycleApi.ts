/**
 * docCycleApi — 문서주기관리 API (/api/v1/hwp/doc-cycles).
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 좌측 양식 목록·우측 주기 단건·저장·삭제만 제공한다 — 예정일 생성은 서버가 저장 시 함께 처리한다
 *   2) 회사코드·작업자는 요청에 넣지 않고 서버 JWT 테넌트로 고정된다
 *   3) 삭제는 POST validate-delete → POST delete 두 단계다 (HTTP DELETE 금지)
 *
 * PIPELINE[HF124] 문서주기관리 API
 * PIPELINE[HF89, HF123] 연관 모듈
 */
// 역할 — 일반 CRUD Axios (10s)
import { http } from "../http";
// 역할 — 서버 공통 응답 형식
import type { CommonResponse } from "@/types/common";

/** 화면 기본 경로 — DocCycleController @RequestMapping과 1:1 */
const BASE = "/api/v1/hwp/doc-cycles";

/** 좌측 양식 목록 1행 — 조회 전용(주기 등록 여부까지 서버가 판단해 내린다) */
export interface DocCycleFormRow {
  tmplCd: string;
  tmplNm: string;
  // 구분 — sys: 시스템양식, usr: 자사양식
  formTy: "sys" | "usr" | string;
  docKind?: string | null;
  // 등록된 주기 — 없으면 null
  cycleCd?: string | null;
  // 주기 등록 여부 Y/N — 삭제 버튼 활성 판정
  ruleYn: "Y" | "N" | string;
  // 양식 사용여부 — 검색·목록 열
  useYn?: "Y" | "N" | string | null;
  // 사용양식 결재선 — 주기 없어도 우측 폼이 채운다. 저장은 apprLineCd
  apprLineCd?: string | null;
  apprLineNm?: string | null;
}

/** 반복 상세 1건 — detailTy에 따라 val1·val2 의미가 달라진다 */
export interface DocCycleDetail {
  // week-day | month-day | month-end | quarter-month | half-month | year-month
  detailTy: string;
  // week-day=요일(1 월 ~ 7 일) / month-day=일(1~31) / quarter·half=주기 내 월 순번 / year-month=월(1~12)
  val1?: number | null;
  // quarter-month·half-month·year-month의 실행일(1~31). 나머지 유형은 null
  val2?: number | null;
}

/** 주기 단건 — 우측 폼 값. 저장은 deptCd·userId로만 하고 명칭은 표시 전용이다 */
export interface DocCycleRule {
  tmplCd: string;
  tmplNm?: string | null;
  // 관리 시작일 yyyyMMdd — 이 날짜 이전 예정일은 만들지 않는다
  baseDt?: string | null;
  // D 매일 / W 매주 / M 매월 / Q 분기 / H 반기 / Y 매년
  cycleCd: string;
  // keep 그대로 / prev 이전 평일 / next 다음 평일
  nonworkRule?: string | null;
  // 마감시각 HHMM
  dueTime?: string | null;
  deptCd?: string | null;
  deptNm?: string | null;
  userId?: string | null;
  userNm?: string | null;
  useYn?: "Y" | "N" | string | null;
  // 사용양식 결재선 — 저장은 코드, 이름은 표시 전용
  apprLineCd?: string | null;
  apprLineNm?: string | null;
  details?: DocCycleDetail[];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 양식 목록을 조회한다 — 구분·사용여부·주기 등록여부 포함
 *   2) 화면 진입·조회 버튼에서 호출한다
 *   3) 조건에 맞는 양식이 없으면 빈 배열
 */
export async function listDocCycleForms(params?: {
  // 양식코드 부분검색어 — 생략하면 전체
  tmplCd?: string;
  // 양식명 부분검색어 — 생략하면 전체
  tmplNm?: string;
  // 사용여부 Y/N — 생략·공백이면 전체
  useYn?: string;
}): Promise<DocCycleFormRow[]> {
  const { data } = await http.get<CommonResponse<DocCycleFormRow[]>>(`${BASE}/forms`, { params });
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 선택 양식의 주기 1건 + 반복 상세를 조회한다
 *   2) 좌측 행을 고를 때마다 호출한다
 *   3) 주기 미설정이면 null — 화면은 빈 폼(신규 등록)으로 둔다
 */
export async function getDocCycle(tmplCd: string): Promise<DocCycleRule | null> {
  const { data } = await http.get<CommonResponse<DocCycleRule | null>>(`${BASE}/get`, {
    params: { tmplCd },
  });
  return data.data ?? null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 주기 1건을 저장한다 — 서버가 같은 트랜잭션에서 예정일을 다시 만든다
 *   2) 우측 폼 저장 버튼에서 호출한다
 *   3) 실패 시 규칙·예정일이 함께 롤백된다
 */
export async function saveDocCycle(row: DocCycleRule): Promise<void> {
  await http.put(`${BASE}/save`, row);
}

/** 삭제 전 주기 존재 검증 — 단건도 tmplCd 객체 배열로 전달한다 */
export async function validateDeleteDocCycles(keys: { tmplCd: string }[]): Promise<void> {
  await http.post(`${BASE}/validate-delete`, keys);
}

/** 검증·확인 완료 주기 삭제 — HTTP DELETE 대신 POST를 사용한다 */
export async function deleteDocCycles(keys: { tmplCd: string }[]): Promise<void> {
  await http.post(`${BASE}/delete`, keys);
}
