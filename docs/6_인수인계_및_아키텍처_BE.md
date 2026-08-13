# haccp-api 인수인계 · 아키텍처

> FE 정본(작성규칙 포함): [`5_인수인계_및_아키텍처_FE.md`](5_인수인계_및_아키텍처_FE.md)  
> Cursor: [`05-handoff-comments.mdc`](../.cursor/rules/05-handoff-comments.mdc) · [`08-haccp-backend.mdc`](../.cursor/rules/08-haccp-backend.mdc)

## 패키지

`com.haccp.{auth|menu|code|pref|log|bas|workflow|ccp|hyg|ops|doc|tsk|sys|common}`

## 레이어

Controller → Service(CUD `@Transactional`) → Mapper+XML → SP  
셸(menu·code·pref·log): Controller→Mapper 허용.

## 주석 밀도

FE와 **동일**. 골드: `AuthService` · `AuthController` · `AuthMapper.xml` · `Document*`.  
PIPELINE 접두사 **`HB`**.

## Two-Tier

Java/DTO/JSON camelCase · SQL/SP lower_snake · `map-underscore-to-camel-case: true`.

## 파일 지도

FE [`10`](17_파일구조_컴포넌트_함수지도.md) §8 BE 전수.
