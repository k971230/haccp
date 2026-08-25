# com.haccp.flow.ca.dto

| 파일 | 역할 |
|---|---|
| `DocCorrectiveDto.java` | 이탈·개선조치 한 건 — 이탈내용·조치내용·조치자명·확인자명 |

작성 화면 저장 요청(`DraftSaveRequest.corrective`)과 문서 상세 응답이 같은 모양을 쓴다.
`mapper/flow/ca/DocCorrectiveMapper.xml` 의 `resultType` 이 이 클래스를 가리킨다 — 패키지를 옮기면 같이 고친다.
