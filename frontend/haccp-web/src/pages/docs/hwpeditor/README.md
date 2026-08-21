# HWP 문서 작성기 (leaf `visitor-log` 등)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../README.md).

레지스트리 `hwpLeaf(tmplCd)`가 이 Page에 `fixedTmplCd`를 고정한다. 화면마다 폴더를 복제하지 않는다.

## 파일

| 파일 | 책임 |
|---|---|
| `HwpDocumentEditorPage.tsx` | 렌더·상태·API·rhwp |
| `HwpDocumentEditorRule.ts` | `LIST_GRID_RULES` · `buildListColumns` · 파일명·서명 평탄화 · `listPersistIdOf` |

## pref 키

`persistId = hwp-document-list-{scrnCd}` — leaf마다 분리. 값 변경 금지.
