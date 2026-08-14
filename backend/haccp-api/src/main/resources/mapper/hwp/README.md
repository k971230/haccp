# mapper/hwp

MyBatis XML — `hwp` (사용양식·문서주기). `namespace`는 인터페이스 FQCN.

| 폴더 | XML | SP |
|------|-----|-----|
| `hwptemplate/` | `HwpTemplateMapper.xml` | `sp_hwp_template_management_*` |
| `doccycle/` | `DocCycleMapper.xml` | `sp_schedule_cycle_management_*` · `sp_tbl_schedule_task_regen_c_000` · `sp_tbl_notification_task_c_000` |

Map 결과에는 `map-underscore-to-camel-case` 가 적용되지 않으므로 별칭을 `"tmplCd"` 처럼 camelCase로 직접 붙인다.

## 관련

- 정본: `docs/8_에이전트_가이드_BE.md` · `mapper/sys/README.md`
