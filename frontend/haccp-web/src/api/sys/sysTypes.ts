/**
 * sysTypes — 시스템 관리 8화면이 공유하는 행 타입.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 도메인별 api 파일이 같은 행 모양을 쓰도록 한곳에 모았다
 *   2) 그리드는 컬럼이 화면마다 달라 느슨한 Record를 기본형으로 둔다
 *   3) 삭제 복합키는 UI가 단건이어도 배열이다 — OPS_DELETE 표준
 *
 * PIPELINE[HF92] 시스템 관리 API 타입
 */

/** 화면마다 컬럼이 다른 조회 결과의 공통 행 */
export type SysRow = Record<string, string | number | boolean | null>;

/** 삭제 대상 복합키 — 시스템 관리 8화면 전부 대리키 idx 하나다 */
export type SysDeleteKey = { idx: number };

/** 공통코드 1행 — 대분류(sub_cd='*')와 세부코드가 같은 모양을 쓴다 */
export type CodeManageRow = {
  idx?: number | null;
  coCd?: string;
  mainCd: string;
  subCd: string;
  codeNm: string;
  sortNo?: number;
  ref1?: string | null;
  ref2?: string | null;
  sysYn?: string;
  useYn?: string;
};

/** 관리용 메뉴 평면 행 — 메뉴 관리 그리드와 권한·로그 화면 트리가 함께 쓴다 */
export type AdminMenuRow = {
  idx?: number;
  menuCd: string;
  menuNm: string;
  hMenuCd?: string | null;
  scrnCd?: string | null;
  sortNo?: number;
  useYn?: string;
};

/** 권한그룹별 화면 권한 1행 — 미설정 화면은 서버가 N으로 채워 보낸다 */
export type RoleScreenRow = {
  idx?: number | null;
  scrnCd: string;
  scrnNm?: string;
  moduleCd?: string;
  readYn: string;
  writeYn?: string;
  modifyYn?: string;
  deleteYn?: string;
  printYn?: string;
  sortNo?: number;
};
