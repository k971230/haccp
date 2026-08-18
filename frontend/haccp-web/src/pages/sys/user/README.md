# 사용자 관리 (`user-management`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../README.md) 5장.

## 파일

| 파일 | 책임 |
|---|---|
| `UserManagementPage.tsx` | 렌더·상태·API 호출·모달 호출. 단일 CRUD 그리드 |
| `UserManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · 컬럼 팩터리(권한그룹·부서·서명 셀 버튼) · `USER_RULES` · `REQUIRED_FIELDS` · `newUserRow` · `matchUser` |

## 화면 규칙

- 사용자 ID(`userId`)는 신규 행에서만 입력 가능
- 권한그룹·부서는 코드 룩업 모달로 고른다. 실제 저장 값은 숨김 컬럼 `usrgrpCd`·`deptCd`이고 그리드에는 `usrgrpNm`·`deptNm`만 보인다
- 비밀번호는 **값을 입력했을 때만** 서버에서 BCrypt로 다시 해싱한다. 빈 값이면 기존 비밀번호 유지
- `empCd`·`posCd`·`lockYn`은 이 화면에서 다루지 않으며 저장 payload에서 제거된다
- 서명은 저장된 사용자에게만 붙일 수 있다(신규 행은 서명 버튼 잠금)

## API · SP · 테이블

| 동작 | API (`api/sys/userApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listUsers` | `sp_user_management_r_000` | `tbl_user` `tbl_dept` `tbl_role` |
| 저장 | `saveUsers` | `sp_user_management_c_000` | `tbl_user` |
| 삭제 검증 | `validateDeleteUsers` | `sp_user_management_delete_blocker_r_000` | `tbl_user` `tbl_grid_pref` `tbl_user_noti_pref` |
| 삭제 | `deleteUsers` | `sp_user_management_d_000` | `tbl_user` `tbl_grid_pref` `tbl_user_noti_pref` |
| 서명 유무 확인 | `fetchMySignInfo()` | `sp_user_management_sign_info_r_000` | `tbl_user` |
| 서명 미리보기 | `fetchUserSignBlob(userId)` | `sp_user_management_sign_r_000` | `tbl_user.sign_img` |
| 서명 업로드·삭제 | `uploadUserSign` · `deleteUserSign` | `sp_user_management_sign_u_000` | `tbl_user.sign_img` |

서명은 바이너리 응답이라 `httpFile`(120s) 인스턴스를 쓴다. 나머지는 `http`(10s).
서명 실물은 `tbl_user.sign_img bytea`에 담기고 목록은 `sign_yn`만 받는다. 그리드의 `_hasSign`은 이 값에서 파생하며 모달에는 `hasSign` prop으로 넘긴다.

## 내 서명 API

`fetchMySignInfo` · `fetchUserSignBlob` · `uploadMySign`도 이 폴더가 아니라 `api/sys/userApi.ts`가 소유한다. 호출부는 냉장·CCP 일지 화면과 HWP 문서작성 화면이다. 경로를 옮기면 그 화면들의 import를 함께 고쳐야 한다.

이미지를 실제로 화면에 그리거나 클립보드에 넣을 때만 blob을 받는다. CCP 행 서명처럼 등록 여부만 보는 자리는 `fetchMySignInfo`(보유여부·파일명)를 쓴다 — 16KB 왕복이 사라진다.

## 모달

```ts
openModal("CodeLookup", { title, options, value, onSelect });  // 권한그룹 · 부서
openModal("UserSign", { userId, userNm, editable });           // 서명 조회·업로드·삭제
```

## pref 키

`scrnCd = user-management` · `persistId = sys-user-management-v2` — 값 변경 금지.
