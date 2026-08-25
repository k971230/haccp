# com.haccp.sys.code.approvalline.dto — 결재선 전송 객체

| 파일 | 역할 |
|---|---|
| `ApprovalLineRow.java` | 결재선 한 줄 |
| `ApprovalLineStepRow.java` | 단계 한 줄 — 순번·역할(WRITE·REVIEW·APPROVE)·담당자 |
| `ApprovalLineDeleteItem.java` | 삭제 키 |

## 단계와 결재 흐름

상신(`REQUEST`)이 결재선 단계를 문서에 스냅샷한다. 이때 **`use_yn='Y'` 인 단계만** 넣는다.
기본 결재선은 `WRITE` → `APPROVE` 2단이고 `REVIEW` 는 꺼 두었다 — 켜면 검토 단계가 살아난다.
