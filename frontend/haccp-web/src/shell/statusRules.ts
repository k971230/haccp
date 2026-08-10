/**
 * statusRules — MES 셸 인프라 모듈.
 *
 * 주요 역할:
 *     1. MesShell(F49) / Page(F115~F156) 지원 유틸
 *     2. 탭·다이얼로그·메시지·검증·단축키 등 횡단 관심사
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음.
 *     - *Page.tsx가 shell을 import(단방향).
 *
 * PIPELINE[F67] 셸 인프라
 * PIPELINE[F49, F52] 연관 모듈
 *
 * 구현내용: 전수 주석(레벨3).
 */
// 편집 잠금 판정용 상태 라벨 정규식 (완료/마감/확정/승인/취소)
const CLOSED_EDIT = /(완료|마감|확정|승인|취소)/;
// 삭제 잠금 판정용 상태 라벨 정규식 (취소 제외)
const CLOSED_DELETE = /(완료|마감|확정|승인)/;
// 위 정규식은 codeMap 라벨(codeNm) 기준으로 편집/삭제 잠금 판정에 사용

/** 작업지시 woStat — C# ViaSysTouchPc_2 / frmPMP1201 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) statusRules — MES 셸 인프라 모듈.
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const WO_STAT = {
  // 등록
  REGISTER: "0",
  // 확정
  CONFIRM: "1",
  // 진행
  PROGRESS: "2",
  // 마감
  CLOSE: "3",
  // 완료
  COMPLETE: "4",
  // 정지
  STOP: "5",
} as const;

/** 공정 prcsStatus — C# Mor 터치PC */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) prcsStatus — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const PRCS_STATUS = {
  // 대기
  WAIT: "01",
  // 시작
  START: "10",
  // 정지
  STOP: "20",
  // 재시작
  RESTART: "30",
  // 완료
  DONE: "90",
  // 취소
  CANCEL: "99",
} as const;

/** 편집 잠금 판정 — 상태 라벨에 완료/마감/확정/승인/취소 포함 시 true */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isEditLocked — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isEditLocked(statusLabel?: string): boolean {
  // 라벨 존재하고 CLOSED_EDIT 패턴 매칭 시 잠금
  return !!statusLabel && CLOSED_EDIT.test(statusLabel);
}

/** 삭제 잠금 판정 — 상태 라벨에 완료/마감/확정/승인 포함 시 true (취소는 삭제 허용) */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isDeleteLocked — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isDeleteLocked(statusLabel?: string): boolean {
  // 라벨 존재하고 CLOSED_DELETE 패턴 매칭 시 잠금
  return !!statusLabel && CLOSED_DELETE.test(statusLabel);
}

/** 코드값 → codeMap 라벨로 편집 잠금 여부 판정 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isEditLockedByCode — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isEditLockedByCode(statusCd?: string, codeMap?: Record<string, string>): boolean {
  // 코드값을 라벨로 변환 후 편집 잠금 판정
  return isEditLocked(codeMap?.[statusCd ?? ""]);
}

/** 코드값 → codeMap 라벨로 삭제 잠금 여부 판정 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isDeleteLockedByCode — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isDeleteLockedByCode(statusCd?: string, codeMap?: Record<string, string>): boolean {
  // 코드값을 라벨로 변환 후 삭제 잠금 판정
  return isDeleteLocked(codeMap?.[statusCd ?? ""]);
}

/** 승인 여부 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isApproved — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isApproved(yn?: string): boolean {
  // useYn Y이면 승인
  return yn === "Y";
}

/** ERP 반영 여부 (재고조정번호 등) */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isErpPosted — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isErpPosted(nb?: string): boolean {
  // 번호가 비어 있지 않으면 ERP 반영됨
  return !!nb && String(nb).trim() !== "";
}

/** 작업지시 마감/완료 여부 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isWoClosed — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isWoClosed(woStat?: string): boolean {
  // 마감(3) 또는 완료(4) 상태
  return woStat === WO_STAT.CLOSE || woStat === WO_STAT.COMPLETE;
}

/** 공정 실적 입력 허용 — IsProductionInputAllowed 간소 대응 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isProductionInputAllowed — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isProductionInputAllowed(prcsStatus?: string, woStat?: string): boolean {
  // 작업지시 마감/완료면 입력 불가
  if (isWoClosed(woStat)) return false;
  // 공정 상태 코드 (없으면 빈 문자열)
  const s = prcsStatus ?? "";
  // 대기/정지/완료/취소가 아니면 입력 허용
  return s !== PRCS_STATUS.WAIT && s !== PRCS_STATUS.STOP && s !== PRCS_STATUS.DONE && s !== PRCS_STATUS.CANCEL;
}

/** 저장된 그리드 행 편집 잠금 — frmSAT2200 Grid2SavedLockCols */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isSavedRow — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function isSavedRow(rowState?: string): boolean {
  // 신규(C)가 아니면 저장된 행
  return !rowState || rowState !== "C";
}
