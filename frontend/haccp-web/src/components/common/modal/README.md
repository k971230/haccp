# 공통 모달 (`components/common/modal`)

특정 화면이 아니라 **여러 도메인이 공유하는 팝업**을 두는 자리. `pages/**`에 팝업 컴포넌트를 만들지 않는다.

## 구성

| 파일 | 역할 |
|---|---|
| `modalTypes.ts` | `ModalPropsMap`(모달 타입 ↔ props 계약) · `ModalType` · `COMMON_MODAL_BODY_H` |
| `GlobalModal.tsx` | 스토어의 `modalType`에 따라 실제 모달을 렌더하는 호스트. `HaccpShell`에 **1회만** 마운트 |
| `CodeLookupModal.tsx` | 코드·명칭 목록에서 1건 선택 (부서·권한그룹 등) |
| `UserSignModal.tsx` | 사용자 서명 조회·업로드·삭제 (`tbl_user.sign_img bytea` 직접 조회) |
| `../../../stores/modalStore.ts` | Zustand: `modalType` · `modalProps` · `openModal` · `closeModal` |

`modalTypes.ts`를 별도로 두는 이유는 스토어와 모달 컴포넌트가 서로를 import 하면 순환 참조가 되기 때문이다. 타입은 이 파일에만 둔다.

## 사용

```ts
const openModal = useModalStore((s) => s.openModal);

openModal("CodeLookup", {
  title: "상위부서 선택",
  options: deptOptions,   // { value, label }[]
  value: row.hdeptCd,
  allowEmpty: true,       // (없음) 행 노출 → 선택 시 빈 값
  onSelect: (v) => patchRow(row, { hdeptCd: v }),
});

// hasSign은 목록 SP의 sign_yn에서 나온 보유 여부다. false면 미리보기 요청 없이 안내만 띄운다
openModal("UserSign", { userId, userNm, editable: isAdmin, hasSign: true });
```

닫기는 모달 내부에서 `closeModal()`로 처리한다. 호출부가 `isOpen` 상태를 들고 있지 않는다.

## 모달 추가 절차

1. `modalTypes.ts`에 props 인터페이스 + `ModalPropsMap` 엔트리 추가
2. 모달 컴포넌트 작성 — 닫기는 `useModalStore.closeModal`
3. `GlobalModal.tsx` switch에 분기 추가
4. 호출부는 `openModal("새타입", props)`만 호출

## 경계

- 확인창·토스트는 여기 만들지 않는다. `shell/dialog.tsx`의 `mesConfirm`·`mesToast`·`DialogHost`가 이미 있다 (중복 구현 금지)
- 한 화면에서만 쓰는 팝업은 공통이 아니다. 해당 도메인 폴더에 둔다
- 본문 높이는 `COMMON_MODAL_BODY_H`로 통일해 모달 크기가 화면마다 달라지지 않게 한다
- 이모지 금지, 사용자 문구는 업무 용어로만 (`01-project-core.mdc`)
