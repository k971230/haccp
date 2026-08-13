/**
 * modalStore — 전역 공통 모달(코드 룩업·사용자 서명) 열림 상태.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 화면마다 모달 상태 useState를 두지 않도록 종류와 props만 전역에 담는다
 *   2) 렌더는 HaccpShell에 한 번 마운트된 GlobalModal이 담당한다 — 화면은 openModal만 부른다
 *   3) 동시에 하나만 연다. 새로 열면 이전 모달은 대체된다 (모달 위 모달 금지)
 *
 * PIPELINE[HF30] Zustand 스토어
 * PIPELINE[HF99] 연관 모듈
 */
// 역할 — 전역 스토어 생성
import { create } from "zustand";
// 역할 — 모달 종류·props 계약
import type { ModalPropsMap, ModalType } from "@/components/common/modal/modalTypes";

/** 공통 모달 상태와 조작 함수 */
interface ModalState {
  /** 열린 모달 종류 — 닫혀 있으면 null */
  modalType: ModalType | null;
  /** 열린 모달에 넘길 props — 종류와 짝을 이룬다 */
  modalProps: ModalPropsMap[ModalType] | null;
  /** 모달 열기 — 종류에 맞는 props만 받는다(컴파일 타임 검증) */
  openModal: <T extends ModalType>(type: T, props: ModalPropsMap[T]) => void;
  /** 모달 닫기 — 종류·props를 함께 비워 다음 열기에 잔상이 남지 않게 한다 */
  closeModal: () => void;
}

export const useModalStore = create<ModalState>((set) => ({
  modalType: null,
  modalProps: null,
  openModal: (type, props) => set({ modalType: type, modalProps: props }),
  closeModal: () => set({ modalType: null, modalProps: null }),
}));
