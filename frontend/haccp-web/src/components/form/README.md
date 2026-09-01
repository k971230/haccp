# form

폼·입력 공용 컴포넌트.

HTML 양식 표는 화면 폴더의 Paper 가 그린다. 여기서는 서명 칸·props·판정 규칙만 둔다.

| 파일 | 역할 |
|---|---|
| `htmlFormPaperShared.tsx` | `HtmlFormPaperProps` · `SignSlot` · `PaperTitleCell` · 기록행·판정 헬퍼 |
| `docFormSearch.ts` | 문서함·첨부 검색 기간 기본값. 검색 UI 는 `SearchArea` |
| `DocFormLayout.tsx` | 옛 작성 셸 — 신규 화면은 `PageCard` + `SearchArea` |

기준관리 5화면은 `HtmlFormTemplatePage` 50:50 프레임. 표준은 수정 불가, 자사는 행추가만.

## 판정 — 적합이 기본이다

현장 기록은 대부분이 적합이다. 빈 값으로 두면 행마다 라디오를 한 번씩 더 눌러야 한다.
**적합으로 깔고 부적합만 눌러 고치게 한다.**

| 어디서 | 무엇 |
|---|---|
| `appendLogRow(rows, phase, judgeCd?)` | 새 기록행 — 기본 `P` |
| `detailToDraftBuf` | 아직 저장 안 한 문서의 항목·기록행을 적합으로 깐다 |
| `allLogRowsPass` · `allItemsPass` | 지면의 **「모두 적합」** 버튼 |

`allItemsPass` 는 **판정 칸이 있는 항목만** 칠한다. 숫자·문자 전용 항목이나 표 머리글까지
칠하면 저장 자료가 더러워진다.

### 판정은 다섯 화면 모두 사람이 정한다

**서버가 판정을 계산하는 곳은 없다.** 화면에서 정한 `judgeCd` 가 그대로 저장된다.

금속검출만 예전에 달랐다. `sp_tbl_ccp_metal_monitor_c_000` 이 감도 5칸으로 계산했고
(`feOnly='O' AND stsOnly='O' AND prodOnly='X' AND feProd='O' AND stsProd='O'` 라야 적합),
화면은 미리 칠하지 않고 `judgeModYn: "Y"` 로 그 계산을 눌렀다. **두 가지가 어긋났다.**

1. 뒤 세 열은 양식에서 「해당 없음」이 기본이라 **고정행에는 입력칸 자체가 없다.**
   값이 안 들어오니 조건이 성립할 수 없어 늘 부적합이 됐다
2. 그걸 덮는 `judgeModYn` 을 **읽는 화면이 없어** 누가 뒤집었는지 아무도 못 봤다.
   실제로 5칸이 전부 `X`(시편 미검출 = 검출기 고장)인데 적합인 기록이 운영에 남아 있었다

그래서 자동 판정을 걷어냈다. 대신 **근거를 같이 채운다.**

### 「모두 적합」이 금속검출에서는 칸도 채운다

```ts
allLogRowsPass(rows, passCells)   // passCells 를 주면 빈 칸을 그 값으로 채운다
```

`CcpMtlPaper` 가 `MTL_HDR[].pass` 로 「적합일 때의 값」을 넘긴다 —
시편(Fe·SUS)은 검출돼야 하니 `O`, **제품만 통과는 검출되면 안 되니 `X`** 다.
**해당 없음 열은 뺀다** — 지면에 입력칸이 없어서 값을 넣으면 화면에 안 보이는 값이 저장된다.
**이미 찍은 칸은 안 덮는다.** 사람이 실제로 본 값이 이긴다.

판정만 바꾸면 **근거는 비었는데 결론만 적합인 종이**가 나온다. 그걸 막는 것이 이 인자다.

`judgeModYn` 은 DB 칸(`judge_mod_yn` NOT NULL)이 남아 있어 왕복만 시킨다. **새로 `Y` 를 붙이지 않는다.**

## 관련
- 시험: `htmlFormJudgeDefault.test.ts` (16건) · `e2e/draft-judge-default.spec.ts`
- 정본: [`docs/7_보안과_파일.md`](../../../../../docs/7_보안과_파일.md)
