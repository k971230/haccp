# .mvn

Maven Wrapper 설정. `./mvnw` 가 여기를 읽어 Maven 을 내려받는다.

**손대지 않는다.** Maven 버전을 바꿀 때만 `wrapper/maven-wrapper.properties` 를 고친다.

| 파일 | 무엇 |
|---|---|
| `wrapper/maven-wrapper.properties` | 내려받을 Maven 버전·URL |
| `wrapper/maven-wrapper.jar` | 부트스트랩 (있는 저장소도 있고 없는 저장소도 있다) |

Wrapper 를 쓰는 이유 — 사람마다 다른 Maven 버전을 깔지 않아도
같은 빌드가 나오게 한다. Jenkins 도 `./mvnw` 를 쓴다.

## 자주 밟는 것

Windows 에이전트에서 `mvnw` 가 Launcher 를 못 찾으면 대개 둘 중 하나다.

- 깨진 `MAVEN_HOME`·`M2_HOME` 이 환경에 남아 있다 (`Jenkinsfile` 이 `unset` 한다)
- 체크아웃이 `mvnw` 를 CRLF 로 받았다 (`.gitattributes` 가 `*.sh` 를 LF 로 고정한다)

## 관련

- 서버 문서: [`../README.md`](../README.md) · [`../PIPELINE.md`](../PIPELINE.md)
