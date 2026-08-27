# form

폼·입력 공용 컴포넌트.

HTML 양식 표는 화면 폴더의 Paper 가 그린다. 여기서는 서명 칸·props·판정 규칙만 둔다.

| 파일 | 역할 |
|---|---|
| `htmlFormPaperShared.tsx` | `HtmlFormPaperProps` · `SignSlot` · `PaperTitleCell` · 기록행·판정 헬퍼 |
| `DocFormLayout.tsx` · `DocFormSearchToolbar.tsx` | 작성 화면 셸 |

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

### 금속검출만 다르다 — 화면이 미리 칠하지 않는다

`sp_tbl_ccp_metal_monitor_c_000` 이 **감도 5칸으로 판정을 계산한다.**
`feOnly='O' AND stsOnly='O' AND prodOnly='X' AND feProd='O' AND stsProd='O'` 라야 적합이다.

그래서 금속 지면은 판정을 미리 안 칠한다. 칠하면 저장하는 순간 서버가 부적합으로 뒤집어
**「보이는 값」과 「저장되는 값」이 달라진다.** 감도 확인도 안 한 행이 적합으로 남는 건
HACCP 에서 하면 안 되는 일이다.

- `detailToDraftBuf` — 양식코드가 `tml_ccp_mtl` 로 시작하면 기본값을 건너뛴다
- `CcpMtlPaper` 의 행추가 — `appendLogRow(..., "")` 로 판정을 비운다

**「모두 적합」은 금속에도 있다.** 대신 `judgeModYn: "Y"` 를 같이 남긴다 —
사람이 정한 판정이라는 뜻이고, SP 는 그때만 서버 계산을 누르고 그 값을 쓴다.
행마다 적합 라디오를 직접 누르는 것과 똑같고, 감사에도 그렇게 남는다.

## 관련
- 시험: `htmlFormJudgeDefault.test.ts` (10건) · `e2e/draft-judge-default.spec.ts` (10건)
- 정본: [`docs/7_보안과_파일.md`](../../../../../docs/7_보안과_파일.md)
