# INDEX — 무엇이 어디 있나

> 개발자: 박승우 · 일자: 2026-09-07
> **생성기가 만든다** — `node scripts/gen_index.mjs`. 손으로 고치지 않는다.

폴더와 그 폴더 README 의 첫 줄을 실물에서 뽑았다.
규칙·읽기 순서는 [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) 가 정본이다.
지금 상태는 [`handoff.md`](handoff.md), 문서 색인은 [`docs/README.md`](docs/README.md).

## 숫자

| | |
|---|---|
| 목차에 오른 폴더 | 204 |
| README 있는 폴더 | 180 |
| **README 없는데 소스가 있는 폴더** | **24** |

## 트리

```
.claude/
    Claude Code 전용 실행 설정이다. 규칙 정본은 아니다 — 정본은 .cursor/rules/ 다
.cursor/
    Cursor 에이전트용 프로젝트 규칙.
  rules/
      이 저장소는 HACCP만 다룬다. 번호는 연속이다.
backend/
    HACCP API 소스 루트. 실행·빌드는 haccp-api/ 안에서 한다.
  haccp-api/
      HACCP API 서버. Spring Boot 3.3.4 · Java 17 · MyBatis 3.0.3 · PostgreSQL.
    .mvn/
        Maven Wrapper 설정. ./mvnw 가 여기를 읽어 Maven 을 내려받는다.
      wrapper/
          Maven Wrapper jar·properties. JDK/Maven 버전을 저장소에 고정한다.
    .run/
        IntelliJ 실행 구성. 팀 공용이라 커밋한다.
    src/
        애플리케이션 소스·리소스 루트 (main).
      main/
          운영 코드·설정·매퍼 XML·매니페스트.
        java/
            Java 소스 루트.
          com/
              Java 패키지 네임스페이스 접두 (com).
            haccp/
                HACCP API 루트 패키지. 화면은 com.haccp.{대}.{중}.
              auth/
                  정본: FE pages/auth/README.md. 골드 AuthService.java. XML mapper/auth/.
                dto/
                    auth 요청·응답 DTO (JSON camelCase).
              board/
                  정본: FE pages/board/README.md. TaskController · CalendarController · DailyTaskGenerationJob. XML mapper/board/.
                dto/  ← README 없음
              code/
                  도메인 code — 공통코드. Controller·Service·Mapper 인터페이스.
                dto/
                    code 요청·응답 DTO (JSON camelCase).
              common/
                  공통 설정·컨텍스트·예외·응답·검증.
                auth/
                    JWT 다음 단계다. 로그인했는지는 JwtFilter 가, 그 화면을 만질 권한이 있는지는 여기가 본다.
                config/
                    Spring 설정 — 요청이 컨트롤러에 닿기 전과 응답이 나간 뒤에 도는 것들.
                context/
                    LoginUser 등 요청 스코프 컨텍스트.
                exception/
                    BizException·GlobalExceptionHandler·사용자 메시지.
                response/
                    공통 API 응답 래퍼.
                validation/
                    삭제 검증(DeleteValidation) 등 공통 검증.
              docs/
                  정본: FE frontend/haccp-web/src/pages/docs/README.md
                documents/
                    화면 경로(/flow/appr/ · /flow/box/document-inbox)와 패키지가 다르다.
                  dto/
                      doc 요청·응답 DTO (JSON camelCase).
                htmlform/
                    기준관리 API는 /api/v1/docs/html-form/{scrnCd} (hyg-process-template · ccp-verify-template · ccp-pkg-template · c…
                  ccphtgtemplate/
                      화면 1개 = 패키지 1개. FE pages/docs/html/ccphtgtemplate/.
                  ccpmtltemplate/
                      화면 1개 = 패키지 1개. FE pages/docs/html/ccpmtltemplate/.
                  ccppkgtemplate/
                      화면 1개 = 패키지 1개. FE pages/docs/html/ccppkgtemplate/.
                  ccpverifytemplate/
                      화면 1개 = 패키지 1개. FE pages/docs/html/ccpverifytemplate/.
                  htmltemplate/
                      화면 1개 = 패키지 1개. FE pages/docs/html/htmltemplate/.
                    dto/
                        버전 삭제 키 HtmlFormVerDeleteItem. 복사·이름·적용은 Controller body — 전용 DTO 없음.
                hwp/
                    화면 1개 = 패키지 1개. 파이프라인 표는 FE pages/docs/README.md 1장 · 이 패키지 상위 com.haccp.docs/README.md.
                  dto/  ← README 없음
                sch/
                    화면 1개 = 패키지 1개. 파이프라인 표는 FE pages/docs/README.md 2장 · 이 패키지 상위 com.haccp.docs/README.md.
                  dto/
                      주기 상세(요일·월 실행일 등)는 tbl_schedule_rule_detail 에 EAV(detail_ty/val1/val2)로 접힌다.
                templates/
                    TemplateController · TemplateService · 파일 볼륨. XML 없음(파일 I/O). 목록 SP는 DocumentMapper.
              draft/
                  URL /draft. 사용 중인 양식을 골라 일자별 작성 문서를 만드는 화면 묶음이다.
                ccpmonitoring/
                    화면 3개 = 컨트롤러 3개. FE pages/draft/ccp-monitoring/.
                  dto/  ← README 없음
                dto/
                    HYG·CCP검증·CCP 모니터링 5화면이 같은 모양을 쓴다. 화면별 dto 로 복제하지 않는다
                html/
                    둘 다 사용여부 Y 인 자사 양식만 작성 대상이다. 표준 예시(_000)는 가상행이라 목록에서 뺀다.
                hwpdoc/
                    경로 /api/v1/draft/hwp-doc/hwp-write — FE SCREEN_PATH 와 같은 칸.
              flow/
                  FE pages/flow 와 같은 칸이다. 작성이 끝난 문서의 결재·보관·이탈조치를 맡는다.
                ca/
                    두 갈래를 맡는다. 섞지 않는다.
                  dto/
                      작성 화면 저장 요청(DraftSaveRequest.corrective)과 문서 상세 응답이 같은 모양을 쓴다.
              log/
                  도메인 log — 화면 조회·UV/PV 로그. Controller·Service·Mapper 인터페이스.
                dto/
                    log 요청·응답 DTO (JSON camelCase).
              menu/
                  도메인 menu — 메뉴·권한. Controller·Service·Mapper 인터페이스.
                dto/
                    menu 요청·응답 DTO (JSON camelCase).
              pref/
                  도메인 pref — 사용자 환경설정. 조회(list)는 Controller → Mapper 직행. 저장(save)만 PrefService (@Transactional).
                dto/
                    pref 요청·응답 DTO (JSON camelCase).
              sys/
                  정본: .cursor/rules/08-haccp-backend.mdc · .cursor/rules/06-operations.mdc · FE 파이프라인 표는 frontend/haccp-web/sr…
                code/
                    FE pages/sys/code 6화면과 1:1. URL /api/v1/sys/code/{scrnCd}.
                  approvalline/
                      화면 1개 = 패키지 1개. 파이프라인 표는 FE pages/sys/README.md.
                    dto/
                        상신(REQUEST)이 결재선 단계를 문서에 스냅샷한다. 이때 use_yn='Y' 인 단계만 넣는다.
                  commoncode/
                      화면코드 common-code-management · XML resources/mapper/sys/code/commoncode/CommonCodeMapper.xml · SP db_sasshacc…
                    dto/
                        저장·삭제만 DTO 다. 조회 목록은 SP 결과 Map 을 그대로 내린다.
                  department/
                      화면코드 department-management · XML resources/mapper/sys/code/department/DepartmentMapper.xml · SP db_sasshaccp…
                    dto/  ← README 없음
                  menu/
                      화면코드 menu-management · XML resources/mapper/sys/code/menu/MenuMgmtMapper.xml · SP db_sasshaccp/01_sp.sql
                    dto/  ← README 없음
                  role/
                      화면코드 role-management · XML resources/mapper/sys/code/role/RoleMgmtMapper.xml · SP db_sasshaccp/01_sp.sql
                    dto/  ← README 없음
                  user/
                      화면코드 user-management · XML resources/mapper/sys/code/user/UserMapper.xml · SP db_sasshaccp/01_sp.sql
                    dto/  ← README 없음
                logs/
                    조회 전용 3화면. 쓰기 API 가 없다 — 이력은 다른 경로가 쌓는다.
                  auditlog/
                      화면코드 audit-log · XML resources/mapper/sys/logs/auditlog/AuditLogMapper.xml · SP db_sasshaccp/01_sp.sql
                    dto/  ← README 없음
                  loginhistory/
                      화면코드 login-history · XML resources/mapper/sys/logs/loginhistory/LoginHistoryMapper.xml · SP db_sasshaccp/01_…
                    dto/  ← README 없음
                  screenusage/
                      화면코드 screen-usage-statistics · XML resources/mapper/sys/logs/screenusage/ScreenUsageMapper.xml · SP db_sassh…
                    dto/  ← README 없음
        resources/
            application.yml·MyBatis mapper·템플릿 매니페스트.
          holidays/
              문서주기 비영업일 판정용. 규칙을 이 저장소에서 계산하지 않는다.
          mapper/
              도메인별 MyBatis XML. SP 호출은 lower_snake. 경로는 mapper/{대}/{중}/ —
            auth/
                MyBatis XML — auth (인증·로그인·JWT). SP sp_tbl_ 호출.
            board/
                MyBatis XML — 게시판(오늘 할 일·일정 캘린더). SP sp_tbl_ · sp_calendar_ 호출.
            code/
                MyBatis XML — code (공통코드). SP sp_tbl_ 호출.
            docs/
                com.haccp.docs. Mapper 인터페이스. 화면(메뉴) 1개 = 폴더 1개.
              documents/
                  골드 XML. DocumentMapper.xml — com.haccp.docs.documents.DocumentMapper
              htmlform/
                ccphtgtemplate/
                    CcpHtgTemplateMapper.xml — com.haccp.docs.htmlform.ccphtgtemplate.CcpHtgTemplateMapper
                ccpmtltemplate/
                    CcpMtlTemplateMapper.xml — com.haccp.docs.htmlform.ccpmtltemplate.CcpMtlTemplateMapper
                ccppkgtemplate/
                    CcpPkgTemplateMapper.xml — com.haccp.docs.htmlform.ccppkgtemplate.CcpPkgTemplateMapper
                ccpverifytemplate/
                    CcpVerifyTemplateMapper.xml — com.haccp.docs.htmlform.ccpverifytemplate.CcpVerifyTemplateMapper
                htmltemplate/
                    HtmlTemplateMapper.xml — com.haccp.docs.htmlform.htmltemplate.HtmlTemplateMapper
              hwp/
                  화면 hwp-template-management. HWP·HTML 양식 카탈로그와 회사 사용양식을 다룬다.
              sch/
                  화면 schedule-cycle-management. 주기 규칙과 예정일 생성을 다룬다. 저장 직후 예정일을 다시 만든다.
            draft/
                com.haccp.draft. Mapper 인터페이스. 화면(메뉴) 1개 = 폴더 1개.
              ccpmonitoring/
                  namespace 는 인터페이스 FQCN 과 같다. 네이티브 SQL 은 삭제 차단 래핑 SELECT 뿐이다.
              html/
                  CcpVerifyDraftMapper.xml — com.haccp.draft.html.CcpVerifyDraftMapper
              hwpdoc/
                  화면 hwp-write. 문서 본문은 첨부(HWP_SRC)로 붙고 여기는 목록·상세만 본다.
            flow/
                결재에 딸린 부수 도메인. 결재 자체(상신·승인·반려·취소)는 mapper/docs/documents 다.
              ca/
                  문서 1건에 개선조치 0..1 건. 빈 payload 는 삭제다.
            log/
                MyBatis XML — log (화면 조회·UV/PV 로그). SP sp_tbl_ 호출.
            menu/
                MyBatis XML — menu (메뉴·권한). SP sp_tbl_ 호출.
            pref/
                MyBatis XML — pref (사용자 환경설정). SP sp_tbl_ 호출.
            sys/
                com.haccp.sys. Mapper 인터페이스의 MyBatis 구현. 화면(메뉴) 1개 = 폴더 1개.
              code/
                  시스템 기준정보 6화면. 회사코드·작업자는 JWT 에서만 온다.
                approvalline/
                    화면 SP 호출만 둔다. 업무 규칙은 SP 안에 있다.
                commoncode/
                    화면 SP 호출만 둔다. 업무 규칙은 SP 안에 있다.
                department/
                    화면 SP 호출만 둔다. 업무 규칙은 SP 안에 있다.
                menu/
                    화면 SP 호출만 둔다. 업무 규칙은 SP 안에 있다.
                role/
                    화면 SP 호출만 둔다. 업무 규칙은 SP 안에 있다.
                user/
                    화면 SP 호출만 둔다. 업무 규칙은 SP 안에 있다.
              logs/
                  조회 전용. 쓰기 SP 가 없다 — 이력은 다른 경로가 쌓는다.
                auditlog/
                    조회 전용 SP.
                loginhistory/
                    조회 전용 SP.
                screenusage/
                    조회 전용 SP.
          templates/
              classpath 템플릿·매니페스트(TSV 등).
            haccp/
                ./mvnw test 로 도는 JUnit 5 테스트. DB·기동 없이 도는 것만 여기 둔다.
              auth/  ← README 없음
                auth/  ← README 없음
                validation/  ← README 없음
                documents/  ← README 없음
                  htmltemplate/  ← README 없음
                hwp/  ← README 없음
                sch/  ← README 없음
                templates/  ← README 없음
              draft/  ← README 없음
                ccpmonitoring/  ← README 없음
                hwpdoc/  ← README 없음
                ca/  ← README 없음
                  user/  ← README 없음
db_sasshaccp/
    PostgreSQL sasshaccp 스키마 정본. 여기 7본이 곧 DB 다 — 손으로 친 DDL·데이터는 남기지 않는다.
docs/
    HACCP SaaS 문서 정본. 10본이다.
  templates/
      표준·사용자 양식 HWP 시드(git 추적). 배포 시 API 이미지에 구워 기동하면 파일 볼륨으로 복사된다.
    usr/
        사용자추가 양식 시드. 화면에서 저장·업로드한 파일을 여기 넣고 커밋하면 다음 배포에 서버 CustomTemplates로 복사된다.
frontend/
    HACCP 웹(React) 소스 루트. 앱은 haccp-web/ 이다.
  haccp-web/
      React 18 · Vite 5 SPA. 로컬 Vite 4173 → API 7070. 가이드: .cursor/rules/09-haccp-frontend.mdc.
    e2e/
        Playwright E2E. 화면이 열리는가가 아니라 업무가 끝까지 도는가를 본다.
    public/
        빌드에 그대로 복사되는 정적 자산.
      manual/
          화면별 사용자 매뉴얼 HTML. 빌드가 dist/manual/ 로 그대로 복사한다.
    scripts/
        FE 로컬 유틸 스크립트.
    src/
        SPA 소스 루트. 이야기 docs/1_시작하기.md · 태그 docs/5_PIPELINE_색인.md · 경로 docs/4_명명과_경로.md · 찾는 법 docs/3_화면_지도.md.
      api/
          Axios HTTP 클라이언트·도메인 API 함수.
        board/
            게시판 화면 API. 오늘 할 일·알림·일정 캘린더.
        docs/
            /docs 대분류 화면이 쓰는 API. 베이스는 apiOf(scrnCd) 가 SCREEN_PATH 로 조립한다.
        draft/
            pages/draft/ 양식 작성 화면 전용 API.
        sys/
            /sys 대분류. 베이스는 apiOf(scrnCd) 가 SCREEN_PATH 로 조립한다 — 화면코드와 1:1 이다.
      components/
          공용 UI·그리드·폼·문서·레이아웃 컴포넌트.
        common/
            특정 업무에 매이지 않은 UI 조각만 둔다. 업무가 붙으면 components/{form,grid,document} 로 간다.
          modal/
              업무를 모르는 모달 껍데기. 제목·본문·버튼 슬롯만 갖는다.
        document/
            문서·HWP/서명·결재 미리보기·인쇄 관련 컴포넌트.
        form/
            폼·입력 공용 컴포넌트.
        grid/
            MES 식 커스텀 그리드. 스물여덟 화면이 같은 것 하나를 쓴다 —
        layout/
            페이지 레이아웃 조각.
        ui/
            버튼·모달 등 저수준 UI. 공통코드 sys-yn 배지는 SysYnBadge.
      config/
          envConfig 등 전역 상수(매직넘버 금지).
      hooks/
          공용 React hooks.
      lib/
          라이브러리 래퍼·유틸 모듈.
      pages/
          화면 페이지. 폴더는 URL 대/중과 같다. 경로 정본 docs/4_명명과_경로.md. 체인 표는 각 영역 README.
        auth/
            로그인만. 평탄. 공개 라우트 /login (브라우저 Path /haccp/login).
        board/
            게시판 대분류. 오늘 할 일·일정 캘린더. URL /board/{scrnCd}.
        docs/
            문서 관리 소스. 골드 구조는 pages/sys/README.md와 같다.
          html-form/
              화면 1개 = 폴더 1개.
            ccphtgtemplate/
                HTML양식 원본 하위. 좌우 50:50 프레임. 지면은 CcpHtgPaper 전용 HTML.
            ccpmtltemplate/
                HTML양식 원본 하위. 좌우 50:50 프레임. 지면은 CcpMtlPaper 전용 HTML.
            ccppkgtemplate/
                HTML양식 원본 하위. 좌우 50:50 프레임. 지면은 CcpPkgPaper 전용 HTML.
            ccpverifytemplate/
                - 좌우 50:50 프레임(HtmlFormTemplatePage). 지면은 CcpChkPaper → HygPrcPaper 동일 HTML.
            htmltemplate/
                일반위생관리 및 공정점검표 기준관리. 사용양식 관리와 같이 검색 헤더 + 왼쪽 양식 그리드 + 오른쪽 지면.
          hwp/
              정본 파이프라인 요약은 상위 pages/docs/README.md.
          sch/
              정본 파이프라인 요약은 상위 pages/docs/README.md 2장.
        draft/
            URL /draft. 사용 중인 양식을 골라 일자별 작성 문서를 만드는 화면 묶음이다.
          ccp-monitoring/
              양식관리 ccp-pkg-template · ccp-htg-template · ccp-mtl-template 에서 사용여부 = 예로 둔
          html/
              URL /draft/html. 양식관리에서 사용여부 = 예로 둔 자사 HTML 양식을 일자별로 작성한다.
          hwp-doc/
              사용양식 관리 hwp-template-management 에서 사용여부 = 예로 둔 HWP 양식만 작성한다.
        flow/
            URL /flow. 작성이 끝난 문서가 결재를 거쳐 보관되기까지의 화면 묶음이다.
          appr/
              URL /flow/appr. 문서 흐름의 결재 구간 3화면이다.
            attach/
                URL /flow/appr/attach. 내가 작성한 문서의 원본·첨부·비고를 관리하고 결재 진행상태를 본다.
          box/
              URL /flow/box. 결재까지 끝난 문서를 모아 보는 보관함이다.
            documentbox/
                정본 파이프라인 요약은 상위 pages/docs/README.md.
          ca/
              URL /flow/ca. 작성 화면에서 이탈로 등록한 문서를 모아 조치를 적는다.
            corrective/
                정본 파이프라인 요약은 상위 pages/docs/README.md.
        sys/
            메뉴바에서 열리는 sys 도메인 9화면 정본.
          code/
              URL /sys/code. 시스템 기준정보 6화면.
            approvalline/
                정본 파이프라인 요약은 상위 pages/sys/README.md.
            commoncode/
                정본 파이프라인 요약은 상위 pages/sys/README.md 1장.
            department/
                정본 파이프라인 요약은 상위 pages/sys/README.md 4장.
            menu/
                정본 파이프라인 요약은 상위 pages/sys/README.md 2장.
            role/
                정본 파이프라인 요약은 상위 pages/sys/README.md 3장.
            user/
                정본 파이프라인 요약은 상위 pages/sys/README.md 5장.
          logs/
              URL /sys/logs. 조회 전용 3화면. 셋 다 LogPageShell 을 공유한다 (좌 트리 + 우 목록).
            auditlog/
                정본 파이프라인 요약은 상위 pages/sys/README.md 6장.
            loginhistory/
                정본 파이프라인 요약은 상위 pages/sys/README.md 6장.
            screenusage/
                정본 파이프라인 요약은 상위 pages/sys/README.md 6장.
      routes/
          React Router·SCREEN_REGISTRY 연동.
      shell/
          정본 이야기: frontend/haccp-web/PIPELINE.md. 태그 HF49 대역 docs/5_PIPELINE_색인.md.
        gridRules/
            그리드 편집·저장 규칙.
      static/
          import 로 끌어 쓰는 자원만 둔다. 빌드가 해시를 붙여 dist/assets 로 낸다.
        img/
            큰 이미지는 번들 크기를 그대로 늘린다. 새로 넣기 전에 압축한다.
      stores/
          Zustand 등 클라이언트 상태.
      styles/
          전역·테마 CSS.
      types/
          공유 TypeScript 타입.
      utils/
          순수 유틸 함수.
nginx/
    운영 edge 컨테이너. TLS 를 여기서 끝내지 않는다 — 호스트 Apache(443)가 종단하고
scripts/
    HACCP 운영·검증 스크립트. 정본 절차는 DEPLOY.md.
tools/  ← README 없음
  rhwp/
      <p align="center">
```

## README 없는 폴더 (24)

`CLAUDE.md` 는 폴더를 새로 만들면 README 를 같이 만들라고 한다. 아래가 그 규칙 밖이다.

- `backend/haccp-api/src/main/java/com/haccp/board/dto` — 소스 8본
- `backend/haccp-api/src/main/java/com/haccp/docs/hwp/dto` — 소스 5본
- `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/dto` — 소스 4본
- `backend/haccp-api/src/main/java/com/haccp/sys/code/department/dto` — 소스 3본
- `backend/haccp-api/src/main/java/com/haccp/sys/code/menu/dto` — 소스 3본
- `backend/haccp-api/src/main/java/com/haccp/sys/code/role/dto` — 소스 7본
- `backend/haccp-api/src/main/java/com/haccp/sys/code/user/dto` — 소스 5본
- `backend/haccp-api/src/main/java/com/haccp/sys/logs/auditlog/dto` — 소스 1본
- `backend/haccp-api/src/main/java/com/haccp/sys/logs/loginhistory/dto` — 소스 1본
- `backend/haccp-api/src/main/java/com/haccp/sys/logs/screenusage/dto` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/auth` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/common/auth` — 소스 2본
- `backend/haccp-api/src/test/java/com/haccp/common/validation` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/docs/documents` — 소스 3본
- `backend/haccp-api/src/test/java/com/haccp/docs/htmlform/htmltemplate` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/docs/hwp` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/docs/sch` — 소스 2본
- `backend/haccp-api/src/test/java/com/haccp/docs/templates` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/draft` — 소스 2본
- `backend/haccp-api/src/test/java/com/haccp/draft/ccpmonitoring` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/draft/hwpdoc` — 소스 1본
- `backend/haccp-api/src/test/java/com/haccp/flow/ca` — 소스 2본
- `backend/haccp-api/src/test/java/com/haccp/sys/code/user` — 소스 1본
- `tools` — 소스 8본

## 관련

- 읽기 순서: [`.cursor/rules/00-bootstrap.mdc`](.cursor/rules/00-bootstrap.mdc)
- 화면 전수: [`docs/3_화면_지도.md`](docs/3_화면_지도.md) — 생성기가 만든다
- SP → 표: [`docs/9_SP_색인.md`](docs/9_SP_색인.md) — 생성기가 만든다
