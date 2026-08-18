# 문서주기관리 (`schedule-cycle-management`)

정본 파이프라인 요약은 상위 [`pages/hwp/README.md`](../README.md) 2장.

## 파일

| 파일 | 책임 |
|---|---|
| `ScheduleCycleManagementPage.tsx` | 렌더·상태·API. 좌 목록 + 우 주기 폼 |
| `ScheduleCycleManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · 주기 상수·날짜 변환·`detailsToForm`/`formToDetails` · `buildFormColumns` |
| `../formType.ts` | 구분 라벨 정본 — 사용양식 관리와 공유 |
| `../FormTypeBadge.tsx` | 헤더 구분 배지 — 사용양식 관리와 같은 색·문구 |

## 화면 규칙

- 좌측은 조회 전용. 양식 등록·삭제는 사용양식 관리 몫
- 검색: 양식코드 · 양식명 · 사용여부(기본 Y, 빈값=전체)
- 목록 열: 양식코드 · 양식명 · 구분 · 사용여부
- 분할 기본 50:50 (범위 약 25~75)
- 양식 1개 = 주기 0..1건. 우측은 그리드가 아닌 단일 폼(업서트)
- 반복설정은 주기 콤보에 따라 영역만 교체 — 매일 안내 / 매주 요일 / 매월 실행일(파랑)·말일 실행(노랑) / 분기·반기·매년 월+일
- 매월 1~31 칩은 고정 칸(`h-9 w-9`). 「말일 실행」은 꺼져 있어도 노랑, 켜면 진한 노랑
- 담당자는 `openModal("CodeLookup")` 재사용. 고르면 소속 부서가 기본값. 담당부서는 읽기 전용
- 주기 없는 양식 기본값: 당일 · 매일 · 그대로 · 18:00 · 담당 빈값 · 사용 Y
- 미저장 변경이 있으면 좌측 행 이동 전에 `mesConfirm`

## API · SP

| 동작 | API (`api/hwp/docCycleApi.ts`) | 서버 |
|---|---|---|
| 양식 목록 | `listDocCycleForms` | `GET /api/v1/hwp/doc-cycles/forms` — `useYn` 검색. SP는 `86_migrate_doc_cycle_form_use_yn.sql`(Jenkins migrate 안 함, DBeaver/수동) |
| 단건 | `getDocCycle` | `GET .../get` |
| 저장 | `saveDocCycle` | `PUT .../save` — 서버가 예정일 재생성까지 처리 |
| 삭제 검증 → 삭제 | `validateDeleteDocCycles` → `deleteDocCycles` | `POST .../validate-delete` → `POST .../delete` |

## pref 키

`scrnCd = schedule-cycle-management` · `persistId = doc-cycle-forms` · split `haccp-split-doc-cycle` — 값 변경 금지.
