/**
 * common.ts — 앱 전역 공통 타입.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 백엔드 CommonResponse·LoginUser·ScreenAuth와 1:1로 대응하는 타입만 둔다
 *   2) 필드명은 백엔드와 완전히 같은 camelCase다 — 이름이 어긋나면 조용히 undefined가 되므로 임의로 바꾸지 않는다
 *   3) React·UI 의존이 없다. 화면 전용 타입은 각 페이지 파일에 둔다
 *
 * PIPELINE[HF32] 공통 모듈
 */

/** API 공통 응답 래퍼 — 백엔드 CommonResponse<T>와 동일 구조 */
export interface CommonResponse<T> {
  success: boolean;
  code: string | null;
  message: string | null;
  data: T;
}

/** 로그인 사용자 — 백엔드 LoginUser(JWT 클레임)와 동일 구조 */
export interface LoginUser {
  /** 회사코드 — 테넌트. 서버가 JWT에서 강제하므로 프론트가 API에 실어 보내지 않는다 */
  coCd: string;
  /** 회사명 — 상단 바 표시용 */
  coNm: string;
  /** 로그인 아이디 — 전 업체 통틀어 유일 */
  userId: string;
  /** 사용자명 — 상단 바·결재선 표시용 */
  userNm: string;
  /** 권한 그룹코드 — ADMIN이면 전권 */
  usrgrpCd?: string;
  /** 부서코드 — 표시용 */
  deptCd?: string | null;
  /** 부서명 — 표시용 */
  deptNm?: string | null;
  /** 세션 식별자 — 화면조회 로그를 잇는 키. 화면에 표시하지 않는다 */
  sid?: string;
}

/**
 * 화면 권한 — 백엔드 ScreenAuthRow와 동일 구조.
 * mes-web의 preTp("RW"/"R") 2단계와 달리 조회·등록·수정·삭제·출력을 각각 Y/N으로 받는다.
 * HACCP는 "기록은 쓰지만 결재 문서는 못 지운다" 같은 조합이 필요해 권한을 쪼갠 것이다.
 */
export interface ScreenAuth {
  scrnCd: string;
  scrnNm?: string;
  moduleCd?: string | null;
  readYn: string;
  writeYn: string;
  modifyYn: string;
  deleteYn: string;
  printYn: string;
  sortNo?: number | null;
}

/** 로그인 API 응답 — 토큰 + 사용자 + 화면권한 */
export interface LoginResponse {
  token: string;
  user: LoginUser;
  /** 화면 권한 목록 — 관리자는 전권이므로 빈 배열이 온다 */
  screens: ScreenAuth[];
}

/** 공통코드 1건 — 콤보는 subCd(값) + codeNm(표시) 조합으로 쓴다 */
export interface CodeRow {
  idx: number;
  coCd: string;
  mainCd: string;
  subCd: string;
  codeNm: string;
  sortNo: number | null;
  ref1: string | null;
  ref2: string | null;
  /** 플랫폼 표준여부 Y/N — Y이면 업체가 수정·삭제할 수 없다 */
  sysYn: string;
  useYn: string;
}
