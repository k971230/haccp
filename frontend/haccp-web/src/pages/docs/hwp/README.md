# hwp — 사용양식 관리 · 공용 HWP 에디터

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../README.md).

HWP 작성 leaf는 `pages/docs/{중}/{scrnCd}/` 가 이 폴더의 `HwpDocumentEditorPage`에 양식코드를 고정한다.

## 파일

| 파일 | 책임 |
|---|---|
| `HwpDocumentEditorPage.tsx` | 렌더·상태·API·rhwp |
| `HwpDocumentEditorRule.ts` | `LIST_GRID_RULES` · `buildListColumns` · 파일명·서명 평탄화 · `listPersistIdOf` |

## pref 키

`persistId = hwp-document-list-{scrnCd}` — leaf마다 분리. 값 변경 금지.
