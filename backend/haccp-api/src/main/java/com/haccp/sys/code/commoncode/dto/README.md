# com.haccp.sys.code.commoncode.dto — 공통코드 전송 객체

저장·삭제만 DTO 다. 조회 목록은 SP 결과 Map 을 그대로 내린다.

| 파일 | 역할 | JSON 키 |
|---|---|---|
| `CommonCodeSaveRow` | 저장 1행 | `idx`·`mainCd`·`subCd`·`codeNm`·`sortNo`·`ref1`·`ref2`·`useYn` |
| `CommonCodeDeleteItem` | 삭제 키 | `idx` |

`coCd`·작업자는 본문에 두지 않는다. JWT 만 쓴다.
