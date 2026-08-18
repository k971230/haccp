/**
 * FormTypeBadge — 사용양식 구분(시스템양식 / 자사양식) 헤더 배지.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 사용양식관리·문서주기관리 패널 헤더가 같은 색·문구를 쓰게 한곳으로 모은다
 *   2) 그리드 컬럼 badge(파랑=시스템, 초록=자사)와 의미를 맞춘다
 *   3) 판정은 formType.isCompanyForm 정본을 쓰고 여기서 다시 나누지 않는다
 *
 * PIPELINE[HF123] 사용양식 구분
 */
// 역할 — 구분 라벨·자사양식 판정 정본
import { FORM_TYPE_LABEL, isCompanyForm } from "./formType";

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 선택 양식의 구분을 헤더 배지로 보여준다
 *   2) 목록·미리보기·주기설정 헤더에서 호출한다
 *   3) 값이 비었을 때(= 구분 없음) 시스템양식 색으로 보여 삭제를 쉽게 누르지 않게 한다
 */
export function FormTypeBadge({
  // 서버 구분 값 — sys/usr 또는 레거시 Y/N. 문서주기는 formTy 를 그대로 넘긴다
  sysYn,
}: {
  sysYn?: string | null;
}) {
  // 자사양식일 때(= usr·레거시 N) 초록, 그 외는 시스템양식 파랑
  const company = isCompanyForm(sysYn);
  return (
    <span
      className={
        company
          ? "shrink-0 rounded px-1.5 py-0.5 text-[11px] font-medium bg-emerald-50 text-emerald-700"
          : "shrink-0 rounded px-1.5 py-0.5 text-[11px] font-medium bg-blue-50 text-blue-700"
      }
    >
      {FORM_TYPE_LABEL[company ? "usr" : "sys"]}
    </span>
  );
}
