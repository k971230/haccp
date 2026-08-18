/**
 * formType — 사용양식 구분(시스템제공 / 사용자추가) 판정 정본.
 *
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) DB sys_yn 은 sys/usr 이 정본이고 레거시 Y/N 값이 남아 있어 판정을 한 곳으로 모은다
 *   2) 표시 문구는 공통코드 sys-yn 이다. 불러오기 팝업 src-ty(시스템/사용자)와 섞지 않는다
 *   3) 삭제 가능 판정만 이 파일이 갖고, 라벨은 화면이 useCommonCodes로 받는다
 *
 * PIPELINE[HF123] 사용양식 구분
 */

/** 목록 구분 공통코드 대분류 — sys 시스템제공, usr 사용자추가. src-ty 와 다르다 */
export const SYS_YN_MAIN_CD = "sys-yn" as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 공통코드 맵에 레거시 Y/N 별칭을 붙인다
 *   2) 옛 행이 Y/N 이어도 그리드가 시스템제공/사용자추가로 보이게 한다
 *   3) sys/usr 문구가 아직 안 왔을 때(= 코드 미로드) 별칭을 붙이지 않는다
 */
export function withSysYnLegacyAliases(
  // sys-yn subCd → codeNm. * 헤더는 훅이 이미 뺀다
  codeMap: Record<string, string>,
): Record<string, string> {
  const next = { ...codeMap };
  if (codeMap.sys) next.Y = codeMap.sys;
  if (codeMap.usr) next.N = codeMap.usr;
  return next;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 사용자추가(usr·레거시 N)인지 판정한다
 *   2) 삭제 가능 판정·구분 badge 색 결정에서 호출한다
 *   3) 값이 비었을 때(= 서버가 구분을 안 준 옛 응답) 시스템제공으로 보아 삭제를 막는다
 */
export function isCompanyForm(
  // 서버 sysYn — sys/usr 또는 레거시 Y/N
  sysYn?: string | null,
): boolean {
  const value = String(sysYn ?? "").toLowerCase();
  return value === "usr" || value === "n";
}
