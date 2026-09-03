# com.haccp.sys.code.approvalline.dto — 결재선 전송 객체

| 파일 | 역할 |
|---|---|
| (목록·단계) | 전용 DTO 를 두지 않는다 — `ApprovalLineMapper.selectApprovalLines` 가 SP 가 만든 JSON 을 `List<String>` 으로 받아 그대로 내린다 |
| `ApprovalLineDeleteItem.java` | 삭제 키 |

## 단계와 결재 흐름

상신(`REQUEST`)이 결재선 단계를 문서에 스냅샷한다. 이때 **`use_yn='Y'` 인 단계만** 넣는다.
기본 결재선은 `WRITE` → `APPROVE` 2단이고 `REVIEW` 는 꺼 두었다 — 켜면 검토 단계가 살아난다.
