/**
 * GlobalModal — 전역 공통 모달 렌더 지점.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) HaccpShell에 한 번만 마운트한다 — 화면은 openModal만 부르고 팝업 JSX를 갖지 않는다
 *   2) modalStore의 modalType으로 어떤 모달을 그릴지 고른다. 닫혀 있으면 아무것도 그리지 않는다
 *   3) 새 공통 모달은 modalTypes.ModalPropsMap 추가 후 여기 분기 한 줄만 늘리면 된다
 *
 * PIPELINE[HF99] 전역 모달 호스트
 */
// 역할 — 열린 모달 종류·props
import { useModalStore } from "@/stores/modalStore";
// 역할 — 모달 종류별 props 계약
import type { CodeLookupModalProps, UserSignModalProps } from "./modalTypes";
// 역할 — 코드 선택 팝업
import { CodeLookupModal } from "./CodeLookupModal";
// 역할 — 사용자 서명 팝업
import { UserSignModal } from "./UserSignModal";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 열려 있는 공통 모달 하나를 렌더한다
 *   2) HaccpShell 레이아웃 최하단에서 DialogHost와 나란히 마운트한다
 *   3) modalType이 null이면 null을 반환해 DOM에 아무것도 남기지 않는다
 */
export function GlobalModal() {
  // 열린 모달 종류 — null이면 닫힘
  const modalType = useModalStore((s) => s.modalType);
  // 열린 모달 props — 종류와 짝이 보장된다(openModal 제네릭)
  const modalProps = useModalStore((s) => s.modalProps);

  if (!modalType || !modalProps) return null;

  switch (modalType) {
    case "CodeLookup":
      return <CodeLookupModal {...(modalProps as CodeLookupModalProps)} />;
    case "UserSign":
      return <UserSignModal {...(modalProps as UserSignModalProps)} />;
    default:
      return null;
  }
}
