# document

문서·HWP/서명·결재 미리보기·인쇄 관련 컴포넌트.

| 파일 | 책임 |
|---|---|
| `RhwpStudioHost.tsx` | rhwp 마운트만. 도구상자는 접지 않음. 버튼·열기·저장은 화면 |
| `ApprovalDocumentPreview.tsx` | 결재/문서함 본문 미리보기. `docKind` 로 HWP/HTML 분기 |
| `HtmlDocumentPreview.tsx` | HTML 지면 Paper 읽기전용. A4 폭 |
| `HwpDocumentPreview.tsx` | HWP 본문 rhwp 읽기전용 |
| `DocumentPreviewPane.tsx` | 미리보기 펼침·접기·높이 드래그 |
| `ApprovalLineSteps.tsx` | 결재 진행상태 가로 스테퍼. 색은 `stepperTone.ts` |
| `stepperTone.ts` | 스테퍼 칸 색 정본 — 완료 파랑 · 현재 노랑 · 반려 빨강 |
| `DocSectionHead.tsx` | 우측 섹션 제목 (파란 배지). 결재 4화면 공용 |
| `DocReasonBox.tsx` | 반려·결재취소 사유 읽기 전용 |
| `DocFileList.tsx` | 원본·첨부 카드 목록. `splitFiles`·뱃지 |
| `DocumentPrintLayer.tsx` | HTML A4 일괄 인쇄 포털 |
| `printHwpDocuments.ts` | HWP export-pdf 후 건별 iframe 인쇄 |
| `printWaitMs.ts` | 인쇄 대화상자 상한. `API_TIMEOUT_FILE_MS` 와 다름 |
| `DocumentApprovalToolbar.tsx` | 전송·전송취소·승인·반려·취소. 사유는 `ReasonAction` 팝업 |

이 폴더는 문서 본문을 그리거나 찍는다. 목록 조회·결재 API 호출은 `pages/flow` 가 맡는다.

## 관련
- 정본: `.cursor/rules/09-haccp-frontend.mdc` · `.cursor/rules/06-operations.mdc`
