# com.haccp.sys.code.user — 사용자 관리 + 서명

화면코드 `user-management` · XML `resources/mapper/sys/code/user/UserMapper.xml` · SP `db_sasshaccp/01_sp.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/code/user-management/list` | `list` | `sp_user_management_r_000` | `tbl_user` `tbl_dept` `tbl_role` |
| PUT | `/api/v1/sys/code/user-management/save` | `save` | `sp_user_management_c_000` | `tbl_user` |
| POST | `/api/v1/sys/code/user-management/validate-delete` | `validateDelete` | `sp_user_management_delete_blocker_r_000` | `tbl_user` `tbl_grid_pref` `tbl_user_noti_pref` |
| POST | `/api/v1/sys/code/user-management/delete` | `delete` | `sp_user_management_d_000` | `tbl_user` `tbl_grid_pref` `tbl_user_noti_pref` |
| GET | `/api/v1/sys/users/{userId}/sign` | `loadSign` | `sp_user_management_sign_r_000` | `tbl_user.sign_img` |
| POST | `/api/v1/sys/users/{userId}/sign` | `uploadSign` | `sp_user_management_sign_u_000` | `tbl_user.sign_img` |
| POST | `/api/v1/sys/users/{userId}/sign/delete` | `deleteSign` | `sp_user_management_sign_u_000` | `tbl_user.sign_img` |
| GET | `/api/v1/sys/users/me/sign` | `loadMySign` | `sp_user_management_sign_r_000` | `tbl_user.sign_img` |
| GET | `/api/v1/sys/users/me/sign-info` | `mySignInfo` | `sp_user_management_sign_info_r_000` | `tbl_user` |

## 규칙

- 비밀번호는 값이 있을 때만 BCrypt로 해싱해 SP에 넘긴다. 빈 값이면 기존 값 유지, 평문은 어디에도 남기지 않는다
- 서명 이미지는 `tbl_user.sign_img bytea`(+ `sign_mime`·`sign_nm`) 한 곳에만 저장한다. 파일 저장소를 쓰지 않으므로 `DocumentFileStorage` 의존이 없다
- 업로드는 `MultipartFile`을 `byte[]`로 읽어 `_sign_u_000`에 넘기고, 삭제는 같은 SP에 세 값을 모두 `null`로 넘긴다
- 조회는 `_sign_r_000`이 `sign_img`·`sign_mime`·`sign_nm`을 반환하고 Controller가 `byte[]`로 응답한다. 목록(`_r_000`)은 실물 대신 `sign_yn`만 파생한다
- **유무 판정에 바이너리를 읽지 않는다.** 서명이 "있는지"만 필요하면 `_sign_info_r_000`(보유여부·파일명·MIME)을 쓴다.
  `_sign_r_000`은 미리보기·클립보드 복사처럼 이미지 실물이 필요할 때만 호출한다. 서명 삭제 전 검사도 info 쪽이다
- 서명 조회·갱신은 네이티브 SQL이 아니라 `_sign_r_000`·`_sign_u_000` SP다. 구 `selectSignPath`·`updateSignPath` 네이티브 statement는 제거되었다
- 삭제는 HTTP DELETE가 아니라 `POST .../sign/delete` (`06-operations.mdc`)

## `me` 경로

`/users/me/sign`은 사용자 관리 화면이 아니라 **냉장·CCP 일지, HWP 문서작성**이 쓴다. 대상 사용자는 경로 파라미터가 아니라 `LoginUserContext.userId()`로 정한다. FE 호출부는 `api/sys/userApi.ts` 하나로 모았으므로 경로 변경 시 그 파일만 고치면 된다.
