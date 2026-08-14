# hwptemplate — 사용양식 관리 (`hwp-template-management`)

화면 1개 = 패키지 1개. 정본 규약: `pages/sys/README.md` · `08-haccp-backend.mdc`.

| 파일 | 역할 |
|------|------|
| `HwpTemplateController` | `/api/v1/hwp/hwp-templates/{list,save,files,apply-file}` |
| `HwpTemplateService` | 목록·저장·이력·불러오기/초기화. sysYn 무시, 신규는 SP가 usr 강제 |
| `HwpTemplateMapper` (+ `mapper/hwp/hwptemplate/`) | `sp_hwp_template_management_*` |

삭제는 법적서류 업로드도 `/api/v1/bas/company-templates/{validate-delete,delete}` 를 쓰므로 **Workflow에 잔류**한다. 그 메뉴를 손볼 때 이전한다.

파일 업로드 I/O는 `doc/TemplateService.saveForm` 그대로.
