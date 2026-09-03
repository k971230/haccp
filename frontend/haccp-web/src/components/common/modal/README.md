# components/common/modal — 공용 모달

업무를 모르는 모달 껍데기. 제목·본문·버튼 슬롯만 갖는다.

업무가 붙은 팝업(양식 선택·HWP 과제)은 그 화면 폴더에 둔다 — 여기 두면 공용이 업무를 알게 된다.

`PasswordChangeModal` 은 화면이 아니라 본인 계정 셀프서비스다. 푸터 키 아이콘이 `openModal("PasswordChange")` 로 연다.

`ReasonActionModal` 은 반려·결재취소처럼 **사유가 필요한 행위**의 공통 팝업이다.
화면은 JSX 를 갖지 않고 `openModal("ReasonAction", { title, onConfirm })` 만 부른다.
textarea 와 확인·닫기 버튼이 팝업 폭을 채운다. 제목은 「결재 취소」·「반려」, 푸터는 항상 확인·닫기다.
