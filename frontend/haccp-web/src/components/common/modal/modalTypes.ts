/**
 * modalTypes — 전역 공통 모달의 종류·props 계약.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) modalStore와 GlobalModal, 각 모달 컴포넌트가 같은 타입을 보게 해 순환 import를 막는다
 *   2) 새 공통 모달을 추가하면 ModalPropsMap에 한 줄 넣고 GlobalModal 레지스트리에 등록한다
 *   3) 여기에는 타입과 상수만 둔다 — 렌더 로직은 각 모달 파일 책임이다
 *
 * PIPELINE[HF99] 공통 모달 타입
 */

/** 코드 룩업 1행 — value=코드, label=표시명 */
export type CodeLookupOption = { value: string; label: string };

/** 룩업·서명 모달 공통 바디 높이 — 그리드와 미리보기를 같은 크기로 맞춘다 */
export const COMMON_MODAL_BODY_H = 280;

/** 코드 룩업 모달 props — openModal("CodeLookup", { ... })로 넘긴다 */
export interface CodeLookupModalProps {
  /** 모달 제목 — 권한그룹·부서·상위부서 등 */
  title: string;
  /** 그리드 열 설정 pref를 저장할 화면코드 — 호출한 화면의 scrnCd */
  scrnCd: string;
  /** 선택 가능 목록 */
  options: CodeLookupOption[];
  /** 현재 선택된 코드 — 행 강조용 */
  value?: string;
  /** true면 맨 위에 (없음) 행을 넣어 빈 코드를 고를 수 있게 한다 */
  allowEmpty?: boolean;
  /** 선택 확정 콜백 — 빈 코드를 고르면 label은 빈 문자열 */
  onSelect: (code: string, label: string) => void;
}

/** 사용자 서명 모달 props — openModal("UserSign", { ... })로 넘긴다 */
export interface UserSignModalProps {
  /** 대상 사용자 ID — 저장된 행만 연다 */
  userId: string;
  /** 서명 등록 여부 — true면 미리보기를 시도한다(서명은 DB 바이너리라 경로가 없다) */
  hasSign?: boolean;
  /** 업로드·삭제 성공 후 호출 — 호출 화면이 목록을 다시 읽는다 */
  onUploaded: () => void;
}

/** 모달 종류 → props 대응표 — 여기에 없는 종류는 열 수 없다 */
export interface ModalPropsMap {
  CodeLookup: CodeLookupModalProps;
  UserSign: UserSignModalProps;
}

/** 열 수 있는 공통 모달 종류 */
export type ModalType = keyof ModalPropsMap;
