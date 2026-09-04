# mapper/sys — SP 호출 전용 XML

`com.haccp.sys.**` Mapper 인터페이스의 MyBatis 구현. 화면(메뉴) 1개 = 폴더 1개.

```
mapper/sys/
 ├ code/
 │   ├ commoncode/ CommonCodeMapper.xml
 │   ├ menu/       MenuMgmtMapper.xml
 │   ├ role/       RoleMgmtMapper.xml
 │   ├ department/ DepartmentMapper.xml
 │   ├ user/       UserMapper.xml
 │   └ approvalline/ ApprovalLineMapper.xml
 └ logs/
     ├ loginhistory/ LoginHistoryMapper.xml
     ├ auditlog/     AuditLogMapper.xml
     └ screenusage/  ScreenUsageMapper.xml
```

`namespace`는 인터페이스 FQCN과 정확히 같다 (`com.haccp.sys.code.commoncode.CommonCodeMapper`).
스캔 경로는 `application.yml`의 `mybatis.mapper-locations` (`classpath:/mapper/**/*.xml`).

## 절대 규약 — 네이티브 SQL 금지

이 폴더의 모든 statement는 **SP 호출만** 한다.

```xml
<!-- 조회: 테이블 SELECT 금지, SP 결과셋만 -->
<select id="selectRows" resultType="map">
  SELECT * FROM sp_department_management_r_000(#{coCd}, #{deptCd}, #{deptNm})
</select>

<!-- CUD: CALL -->
<update id="save" statementType="CALLABLE">
  CALL sp_department_management_c_000(...)
</update>
```

**스키마는 안 붙인다** — 접속 URL 의 `currentSchema=sasshaccp` 와 DB `search_path` 가 잡는다.

- `SELECT ... FROM tbl_*` · `INSERT`/`UPDATE`/`DELETE` 직접 작성 금지
- 조인·집계·정렬도 SP 안에서 끝낸다. XML은 파라미터 바인딩만 담당
- 예외적으로 필요한 SQL이 생기면 SP를 새로 만든다. XML에 넣지 않는다

과거 `SystemMapper.xml`의 `selectSignPath`·`updateSignPath` 네이티브 2건은 `sp_user_management_sign_r_000`·`_sign_u_000` 호출로 대체되었다.

## SP 이름 규약

`sp_{화면명}_{r|c|d|u}_{nnn}` — lower_snake, `sp_tbl_` 접두를 쓰지 않는다 (`07-haccp-db.mdc`).
삭제 검증 전용은 `sp_{화면명}_delete_blocker_r_000`.
테이블 단위 `sp_tbl_*` 규약은 docs·bas 등 업무 도메인과 로그 적재에만 남는다.
`AuditLogMapper.insertAudit`이 부르는 `sp_tbl_audit_log_c_000`은 화면이 아니라 `tbl_audit_log` 테이블 단위 적재라 예외적으로 `sp_tbl_` 이름을 그대로 쓴다.

| 폴더 | SP (전명) | 테이블 |
|---|---|---|
| commoncode | `sp_common_code_management_r_000` · `sp_common_code_management_r_001` · `sp_common_code_management_c_000` · `sp_common_code_management_delete_blocker_r_000` · `sp_common_code_management_d_000` | `tbl_code` |
| menu | `sp_menu_management_r_000` · `sp_menu_management_c_000` · `sp_menu_management_delete_blocker_r_000` · `sp_menu_management_d_000` | `tbl_menu` `tbl_screen` `tbl_role_screen` |
| role | `sp_role_management_r_000` · `sp_role_management_c_000` · `sp_role_management_delete_blocker_r_000` · `sp_role_management_d_000` · `sp_role_management_screen_r_000` · `sp_role_management_screen_c_000` | `tbl_role` `tbl_role_screen` `tbl_screen` `tbl_user` |
| department | `sp_department_management_r_000` · `sp_department_management_c_000` · `sp_department_management_delete_blocker_r_000` · `sp_department_management_d_000` | `tbl_dept` `tbl_user` |
| user | `sp_user_management_r_000` · `sp_user_management_c_000` · `sp_user_management_delete_blocker_r_000` · `sp_user_management_d_000` · `sp_user_management_sign_info_r_000` · `sp_user_management_sign_r_000` · `sp_user_management_sign_u_000` | `tbl_user` `tbl_dept` `tbl_role` `tbl_grid_pref` `tbl_user_noti_pref` |
| approvalline | `sp_tbl_approval_line_r_000` · `sp_tbl_approval_line_c_000` · `sp_tbl_approval_line_delete_blocker_r_000` · `sp_tbl_approval_line_d_000` | `tbl_approval_line` `tbl_approval_line_step` |
| loginhistory | `sp_login_history_r_000` | `tbl_login_log` `tbl_user` |
| auditlog | `sp_audit_log_r_000` · `sp_tbl_audit_log_c_000`(AuditWriter 적재) | `tbl_audit_log` `tbl_user` |
| screenusage | `sp_screen_usage_statistics_r_000` | `tbl_view_stat_daily` `tbl_menu` `tbl_screen` |

사이드바 트리는 이 폴더가 아니다: `sp_menu_nav_r_000` (`mapper/menu`).

## 바인딩 규약

- Two-Tier: SP 파라미터·컬럼은 lower_snake, 앱 DTO/JSON은 camelCase. XML의 `#{}` 키는 **camelCase**로 받는다
- `co_cd`는 항상 `LoginUserContext.coCd()`에서 온 값을 서비스가 넘긴다. 요청 본문의 회사코드를 믿지 않는다
- 조회 `resultType="map"`은 lower_snake 키로 돌아오며 FE `camelizeRows`가 변환한다
- CUD는 `statementType="CALLABLE"` + `CALL sp_...(...)`, 서비스가 `@Transactional`로 감싼다. SP 내부 자율 COMMIT 금지
- 서명 이미지는 `tbl_user.sign_img bytea`다. `#{signImg, jdbcType=BINARY}`로 넘기고 조회는 `resultType="map"`으로 `byte[]`를 받는다
- 서명 유무만 필요한 statement는 `_sign_info_r_000`을 부른다. `bytea`를 SELECT 목록에 넣으면 16KB급 이미지가 매 확인마다 왕복한다

## 오류 전파

SP가 `RAISE EXCEPTION ... ERRCODE='45000'`을 던지면 `SqlUserMessage`가 업무 문구를 뽑아 400으로 내려보내고 FE `mesError(e)`가 토스트한다. XML에서 오류를 삼키지 않는다.

## 타 도메인이 참조하는 SP

다음 3개는 `sys` 밖에서도 호출한다. 시그니처·컬럼 변경 시 해당 경로 회귀가 필수다.

| SP | 호출부 | 영향 |
|---|---|---|
| `sp_common_code_management_r_001` | `mapper/code/CodeMapper.xml` | 전 화면 공통코드 콤보 |
| `sp_menu_nav_r_000` | `mapper/menu/MenuMapper.xml` | 사이드바 메뉴 트리 |
| `sp_role_management_screen_r_000` | `mapper/auth/AuthMapper.xml` | 로그인 후 화면·버튼 권한 |
