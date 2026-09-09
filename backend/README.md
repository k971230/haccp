# backend

HACCP API 소스 루트. 실행·빌드는 [`haccp-api/`](haccp-api/) 안에서 한다.

## 하위

| 경로 | 무엇 |
|---|---|
| [`haccp-api/`](haccp-api/) | Spring Boot 3.3.4 · Java 17 · MyBatis 3.0.3 · PostgreSQL |

모듈은 하나다. 늘릴 계획이 없다 — 이 폴더가 남아 있는 것은
프론트(`frontend/`)와 층을 나란히 보기 위해서다.

## 어디를 보나

여기는 **backend 에만 있는 것**만 적는다. 하려는 일로 찾는 표는
[`README.md`](../README.md) 「어디를 보나」가 정본이다 — 그 표를 여기 다시 적지 않는다.

| 하려는 일 | 볼 곳 |
|---|---|
| 기동 순서·요청이 지나는 길 | [`haccp-api/PIPELINE.md`](haccp-api/PIPELINE.md) |
| 백엔드·DB 규칙 | `.cursor/rules/08-haccp-backend.mdc` · `07-haccp-db.mdc` |

## 변경

- 2026-09-09 — 루트 README 와 겹치던 네 줄을 빼고 backend 고유 두 줄만 남겼다
- 2026-08-26 — 죽은 문서 링크를 새 8본으로 옮기고 PIPELINE 을 가리키게 했다
