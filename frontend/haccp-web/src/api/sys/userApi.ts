/**
 * userApi — 사용자 관리 화면 API + 서명 이미지 API (/api/v1/sys/user-management, /api/v1/sys/users).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 서명 API는 사용자 관리 화면뿐 아니라 냉장 일지·HWP 문서작성도 쓴다 — 사용자 도메인이 소유한다
 *   2) 이미지 업로드·조회는 httpFile 인스턴스(120s)로, 나머지는 http(10s)로 나눈다
 *   3) 삭제는 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HF92] 사용자 관리·서명 API
 */
// 역할 — 일반 CRUD·파일 Axios 인스턴스
import { http, httpFile } from "../http";
// 역할 — 공통 성공 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — MyBatis Map snake_case → 그리드 camelCase 정규화
import { camelizeRows } from "@/lib/camelKeys";
// 역할 — 사용자 행·삭제키 타입
import type { SysDeleteKey, SysRow } from "./sysTypes";

/** 화면 기본 경로 — Controller @RequestMapping과 1:1 */
const BASE = "/api/v1/sys/user-management";
/** 서명 이미지 기본 경로 — 화면 경로와 분리된 리소스 경로 */
const SIGN_BASE = "/api/v1/sys/users";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 사용자 목록을 조회한다 — 부서명·권한그룹명이 조인되어 내려온다
 *   2) 사용자 관리 진입·조회와 로그인 이력 좌측 트리에서 호출한다
 *   3) 조건에 맞는 사용자가 없으면 빈 배열
 */
export async function listUsers(params?: {
  // 아이디 부분검색어 — 생략하면 전체
  userId?: string;
  // 성명 부분검색어 — 생략하면 전체
  userNm?: string;
  // 부서코드 정확일치 — 좌측 부서 트리 선택값
  deptCd?: string;
  // 사용여부 Y|N — 생략하면 전체
  useYn?: string;
}): Promise<SysRow[]> {
  const { data } = await http.get<CommonResponse<SysRow[]>>(`${BASE}/list`, { params });
  return camelizeRows<SysRow>(data.data as unknown as Record<string, unknown>[]);
}

/** 변경된 사용자 행 저장 — 비밀번호는 값이 있을 때만 BCrypt로 다시 해싱된다 */
export async function saveUsers(rows: SysRow[]): Promise<void> {
  await http.put(`${BASE}/save`, rows);
}

/** 삭제 전 참조 검증 — 단건도 idx 객체 배열로 전달한다 */
export async function validateDeleteUsers(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/validate-delete`, keys);
}

/** 검증·확인 완료 사용자 삭제 — HTTP DELETE 대신 POST를 사용한다 */
export async function deleteUsers(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/delete`, keys);
}

/**
 * 지정 사용자 서명 이미지 업로드 — 사용자 관리 서명 팝업.
 * multipart는 httpFile 타임아웃을 쓴다.
 */
export async function uploadUserSign(
  // 대상 사용자 ID — 본인이면 me와 동일 효과
  userId: string,
  // 서명 이미지 파일
  file: File,
  // 팝업 닫기·취소 시 요청 중단용
  signal?: AbortSignal,
): Promise<void> {
  const form = new FormData();
  // 서명 이미지 파일 — 서버 MultipartFile name=file
  form.append("file", file);
  await httpFile.post<CommonResponse<void>>(
    `${SIGN_BASE}/${encodeURIComponent(userId)}/sign`,
    form,
    { signal },
  );
}

/**
 * 지정 사용자 서명 삭제 — tbl_user.sign_img를 NULL로 비운다.
 * HTTP DELETE 금지 규약에 따라 POST .../sign/delete.
 */
export async function deleteUserSign(
  // 대상 사용자 ID
  userId: string,
  // 팝업 닫기·취소 시 요청 중단용
  signal?: AbortSignal,
): Promise<void> {
  await http.post(`${SIGN_BASE}/${encodeURIComponent(userId)}/sign/delete`, {}, { signal });
}

/** 서명 메타데이터 — 이미지 없이 보유여부·파일명만 */
export interface SignInfo {
  // 서명 보유여부 Y|N — 행 서명 적용 가능 판정에 쓴다
  signYn: string;
  // 원본 파일명 — 미등록이면 빈 문자열
  signNm: string;
  // 이미지 MIME — 미등록이면 빈 문자열
  signMime: string;
}

/**
 * 로그인 사용자 서명 보유여부·파일명 조회 — 이미지를 받지 않는 가벼운 확인용.
 * 미등록이어도 정상 응답이며 signYn이 'N'이다. 실물이 필요할 때만 blob API를 쓴다.
 */
export async function fetchMySignInfo(): Promise<SignInfo> {
  const { data } = await http.get<CommonResponse<SignInfo>>(`${SIGN_BASE}/me/sign-info`);
  return data.data as SignInfo;
}

/**
 * 지정 사용자 서명 이미지 Blob — 서명 팝업 미리보기.
 * 미등록·오류는 Axios 예외로 전파한다.
 */
export async function fetchUserSignBlob(
  // 대상 사용자 ID
  userId: string,
  // 팝업 닫기 시 미리보기 요청 중단용
  signal?: AbortSignal,
): Promise<Blob> {
  const { data } = await httpFile.get<Blob>(`${SIGN_BASE}/${encodeURIComponent(userId)}/sign`, {
    responseType: "blob",
    signal,
  });
  return data;
}

/**
 * 로그인 사용자 서명 이미지 업로드 — 문서작성 「서명 복사」 미등록 시 즉시 등록.
 * 서명은 DB 바이너리로 저장되므로 응답 본문이 없다. 실물이 필요하면 fetchMySignImage로 다시 받는다.
 * multipart는 httpFile 타임아웃을 쓴다.
 */
export async function uploadMySign(
  // 서명 이미지 파일 — png/jpg
  file: File,
): Promise<void> {
  const form = new FormData();
  // 서명 이미지 파일 — 서버 MultipartFile name=file
  form.append("file", file);
  await httpFile.post<CommonResponse<void>>(`${SIGN_BASE}/me/sign`, form);
}
