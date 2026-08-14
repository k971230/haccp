# 문서주기관리 (`schedule-cycle-management`)

화면 1개 = 폴더 1개. 골드: [`pages/sys/README.md`](../../sys/README.md).

## 파일

| 파일 | 책임 |
|---|---|
| `ScheduleCycleManagementPage.tsx` | 렌더·상태·API. 좌 30% 조회 전용 목록 + 우 70% 주기 폼 |
| `ScheduleCycleManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · 주기 상수·날짜 변환·`detailsToForm`/`formToDetails` · `buildFormColumns` |
| `../formType.ts` | 구분 라벨 정본 — 사용양식 관리와 공유 |

## 화면 규칙

- 좌측은 조회 전용. 양식 등록·삭제는 사용양식 관리 몫
- 양식 1개 = 주기 0..1건. 우측은 그리드가 아닌 단일 폼(업서트)
- 반복설정은 주기 콤보에 따라 영역만 교체 — 매일 없음 / 매주 요일 / 매월 실행일·말일 / 분기·반기·매년 월+일
- 담당부서·담당자는 `openModal("CodeLookup")` 재사용. 담당자를 고르면 소속 부서가 함께 채워진다
- 미저장 변경이 있으면 좌측 행 이동 전에 `mesConfirm`

## API · SP

| 동작 | API (`api/hwp/docCycleApi.ts`) | 서버 |
|---|---|---|
| 양식 목록 | `listDocCycleForms` | `GET /api/v1/hwp/doc-cycles/forms` |
| 단건 | `getDocCycle` | `GET .../get` |
| 저장 | `saveDocCycle` | `PUT .../save` — 서버가 예정일 재생성까지 처리 |
| 삭제 검증 → 삭제 | `validateDeleteDocCycles` → `deleteDocCycles` | `POST .../validate-delete` → `POST .../delete` |

## pref 키

`scrnCd = schedule-cycle-management` · `persistId = doc-cycle-forms` · split `haccp-split-doc-cycle` — 값 변경 금지.
