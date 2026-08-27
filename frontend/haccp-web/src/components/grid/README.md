# grid

MES 식 커스텀 그리드. 스물여덟 화면이 **같은 것 하나**를 쓴다 —
여기가 무르면 전 화면이 같이 무른다.

| 파일 | 맡는 것 |
|---|---|
| `MesDataGrid` | 조회 전용. 편집 없음 |
| `MesEditableGrid` | 편집. 셀 단위 입력·검증·행 상태(C/U) |
| `useMesTable` | 둘의 속. TanStack Table + pref 로드/저장 |
| `GridChrome` | 툴바·헤더·필터행·푸터 |
| `gridNav` | 키보드 좌표 (`nextRowIndex` · `nextCell` · `isTypingTarget`) |
| `gridPref` | 열 설정 v1/v2 파싱·직렬화 |
| `useGridVirtual` | 가상 스크롤 |
| `gridCsv` | CSV 내보내기 |

## 있는 기능

정렬(다중 정렬 Shift) · 컬럼별 필터 · 결과 내 검색 · 열 표시/숨김 · 열 순서 끌어놓기 ·
열 너비 조절 · 왼쪽 틀 고정 · 전체 선택 · CSV 내보내기 · 가상 스크롤 · 총/표시 건수.

## 단축키

**Ctrl·Meta 조합은 하나도 쓰지 않는다.** 새로고침·저장·검색·인쇄·주소창·복사·붙여넣기를
그리드가 뺏으면, 사용자는 브라우저가 고장난 줄 안다.

| 키 | 조회 | 편집 |
|---|---|---|
| `↑` `↓` | 행 이동 (끝에서 **클램프** — 순환 안 함) | 같음 |
| `Tab` `Shift+Tab` | 안 씀 — 네이티브 포커스 이동 | 셀 이동. **그리드 끝이면 preventDefault 안 함** → 밖으로 나간다 |
| `Enter` `F2` | 안 씀 | 셀 편집 열기 |
| `Delete` `Backspace` | 안 씀 | 셀 비우기 |
| `Escape` | 열 메뉴 닫기 | 편집칸만 닫는다 — **친 값은 남는다** (아래) |
| 헤더 클릭 | 정렬 토글 | 같음 |
| `Shift` + 헤더 클릭 | 다중 정렬(순번 표시) | 같음 |

`F2` 는 엑셀의 「셀 편집」과 같고 브라우저가 안 쓰는 키다.

### Escape 는 「취소」가 아니라 「닫기」다

엑셀과 다르다. 타이핑이 곧바로 행 버퍼로 들어가고 Escape 는 편집칸만 닫는다 —
**친 값은 남고 행은 「변경」으로 표시된다.** DB 에 들어가는 시점은 어디까지나 「저장」이다.

Escape 는 **셀 선택과 키보드 포커스를 지킨다** (`cancelEdit`).
2026-08-27 이전에는 `setEditCell(null)` 만 해서 포커스가 `body` 로 빠졌고,
그 뒤 방향키·F2·Delete 가 전부 죽었다 — 다시 마우스로 눌러야 살아났다.
키보드로 기록을 치는 현장에서 손을 멈추게 하는 종류의 결함이다.
`focus()` 는 **편집칸이 사라진 뒤**(rAF) 불러야 한다. 먼저 부르면 unmount 되면서 다시 빠진다.

**두 관문이 키를 흘려보낸다** — 하나라도 빠지면 검색칸에서 글자를 못 지운다.

```ts
if (view.activeCell?.isEditing) return;   // 편집 중이면 안 가로챈다
if (isTypingTarget(e)) return;            // input·select·textarea 안이면 안 가로챈다
```

## CSV

`cols`(지금 보이는 열)와 `view.displayRows`(거른 뒤 행)만 담는다 —
**숨긴 열은 안 나가고, 거르기 전 전부도 안 나간다.**
엑셀에서 한글이 안 깨지게 맨 앞에 BOM(`﻿`)을 붙인다.

## 열 설정은 아이디별이다

`tbl_grid_pref` — 키는 `co_cd + user_id + scrn_cd + grid_id`.
`grid_id` 가 화면이 넘긴 `persistId` 다. **`persistId` 는 절대 안 바꾼다** —
바꾸면 그 화면 사용자 전원의 열 너비·숨김이 초기화된다. `grid_id` 는 30자 제한이다.

| 저장한다 | 안 한다 |
|---|---|
| 숨김 · 순서 · 너비 (`pref_json` v2, 500ms debounce) | 정렬 · 필터 · 검색어 — **세션만** |

정렬까지 저장하면 어제 걸어 둔 정렬 때문에 오늘 조회가 이상해 보인다.

## 시험할 때 걸리는 것 셋

1. **셸은 먼저 연 탭을 mount 한 채 숨긴다.** 오늘 할 일이 늘 남아 있어서
   `page.locator(".mes-grid-wrap").first()` 는 **안 보이는 탭**을 집는다.
   `:visible` 로 거른다.
2. **가상 스크롤이다.** 총 550건이어도 `tbody tr` 은 스물 몇 개뿐이다.
   목록 전체를 DOM 으로 판정하면 안 된다 — 푸터의 총 건수나 DB 를 본다.
   푸터는 거르면 「총 550건 · 표시 3건」이 된다. **총 건수는 안 줄어든다.**
3. **자리를 숫자로 박으면 안 된다.**
   - 번호 열(rownum) `th` 에는 `.mes-th-inner` 가 없다 → 헤더 목록과 셀 목록의 번호가 하나씩 밀린다.
     그래서 「로그아웃 일시로 정렬하고 로그인 일시를 읽는」 일이 실제로 벌어졌다.
   - 필터 행도 번호 열 `th` 에는 입력이 없다 → 입력만 세면 또 밀린다.
   - `td:has(.mes-cell-editable)` 은 **편집이 열리면 그 칸이 목록에서 빠진다** →
     `.first()` 가 옆 칸을 가리켜 시험이 헛통과한다.

   전부 **열 이름으로** 찾는다.

## 관련
- 시험: `e2e/grid-features.spec.ts` (35건) · `e2e/shell-grid.spec.ts` · `src/components/grid/*.test.ts`
- 정본: [`docs/2_화면_추가하기.md`](../../../../../docs/2_화면_추가하기.md) · [`docs/4_명명과_경로.md`](../../../../../docs/4_명명과_경로.md)

## 날짜 셀 (`type: "date"`)

이 저장소의 날짜 컬럼은 전부 `varchar(8)` **`YYYYMMDD`** 다
(`base_dt`·`occur_dt`·`action_dt`·`due_dt`·`retention_until`).
화면의 `<input type="date">` 는 `YYYY-MM-DD` **10자**를 준다.

그래서 `MesEditableGrid` 가 양쪽을 맞춘다 — 화면마다 변환하지 않는다.

| 언제 | 무엇 |
|---|---|
| 표시 | `toInputDate` — `20260827` → `2026-08-27`. `MesDataGrid` 의 `fmtDate` 와 같은 모습 |
| 편집기에 넣을 때 | `toInputDate` — 안 바꾸면 달력이 값을 못 읽어 빈 `mm/dd/yyyy` 로 보인다 |
| 편집기에서 나올 때 | `fromInputDate` — `YYYYMMDD` 로 되돌린다 |

**되돌리지 않으면 10자가 그대로 나가 DB 가 `22001`(문자열 잘림)로 막는다.**
개선조치 조치일이 실제로 그렇게 저장이 안 됐다. 새 화면이 `type: "date"` 를 써도
같은 일이 안 나게 그리드 한 곳에서 처리한다.
