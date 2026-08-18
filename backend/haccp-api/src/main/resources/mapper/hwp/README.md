# mapper/hwp — SP 호출 전용 XML

`com.haccp.hwp.**` Mapper 인터페이스의 MyBatis 구현. 화면(메뉴) 1개 = 폴더 1개.

```
mapper/hwp/
 ├ hwptemplate/ HwpTemplateMapper.xml
 └ doccycle/    DocCycleMapper.xml
```

`namespace`는 인터페이스 FQCN과 정확히 같다 (`com.haccp.hwp.hwptemplate.HwpTemplateMapper`).
스캔 경로는 `application.yml`의 `mybatis.mapper-locations` (`classpath*:mapper/**/*.xml`).

## 절대 규약 — 네이티브 SQL 금지

이 폴더의 모든 statement는 **SP 호출만** 한다.

```xml
<select id="selectHwpTemplates" resultType="map">
  SELECT * FROM sp_hwp_template_management_r_000(#{coCd}, #{tmplCd}, #{tmplNm})
</select>

<update id="saveHwpTemplate" statementType="CALLABLE">
  CALL sp_hwp_template_management_c_000(...)
</update>
```

- `SELECT ... FROM tbl_*` · `INSERT`/`UPDATE`/`DELETE` 직접 작성 금지
- 조인·집계·정렬도 SP 안에서 끝낸다. XML은 파라미터 바인딩만 담당
- Map 결과는 `map-underscore-to-camel-case`가 적용되지 않으므로 별칭을 `"tmplCd"`처럼 camelCase로 직접 붙인다

## SP 이름 규약

| 폴더 | XML | SP |
|------|-----|-----|
| `hwptemplate/` | `HwpTemplateMapper.xml` | `sp_hwp_template_management_*` |
| `doccycle/` | `DocCycleMapper.xml` | `sp_schedule_cycle_management_*` · `sp_tbl_schedule_task_regen_c_000` · `sp_tbl_notification_task_c_000` |

목록 SP 시그니처 변경 migrate(`86`·`87`)는 Jenkins가 안 돌린다. DBeaver/수동.

## 관련

- 정본: `docs/8_에이전트_가이드_BE.md` · `mapper/sys/README.md`
- 패키지: `com.haccp.hwp/README.md`
