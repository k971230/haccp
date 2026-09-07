# com.haccp.sys.code.approvalline.dto — 결재선 전송 객체

| 파일 | 역할 |
|---|---|
| `ApprovalLineRow.java` | 헤더+단계 — 목록·저장 Body |
| `ApprovalLineStepRow.java` | 단계 1행 |
| `ApprovalLineDeleteItem.java` | 삭제 키 |

## 단계와 결재 흐름

상신(`REQUEST`)이 결재선 단계를 문서에 스냅샷한다. 이때 **`use_yn='Y'` 인 단계만** 넣는다.
기본 결재선은 `WRITE` → `APPROVE` 2단이다. 검토 단계는 없다.
