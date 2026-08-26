# 5. PIPELINE 색인 — 태그에서 파일로

> 개발자: 박승우 · 일자: 2026-08-26
> 소스의 `PIPELINE[HFn]` / `PIPELINE[HBn]` 주석과 1:1 이다.

코드에 태그를 달아 두고 여기서 파일을 찾는다.
「HF130 이 뭐였지」를 검색 없이 알 수 있게 하려는 표다.

**이 표는 손으로 고치지 않는다.** 소스에서 뽑는다 —
손으로 적으면 태그가 늘 때마다 어긋난다.

```sh
# 다시 뽑기 (태그를 더한 뒤)
grep -rho "PIPELINE\[H[FB][0-9]*" frontend/haccp-web/src backend/haccp-api/src | sort -u
```

업무가 어떤 순서로 흐르는지는 태그가 아니라 파이프라인 문서를 본다 —
[`backend/haccp-api/PIPELINE.md`](../backend/haccp-api/PIPELINE.md) ·
[`frontend/haccp-web/PIPELINE.md`](../frontend/haccp-web/PIPELINE.md).

---

## 프론트 (HF) — 85개

| 태그 | 파일 | 무엇 |
|---|---|---|
| `HF1` | `frontend/haccp-web/src/main.tsx` | React 진입점 |
| `HF2` | `frontend/haccp-web/src/main.tsx` | 연관 모듈 |
| `HF3` | `frontend/haccp-web/src/api/documentApi.ts` | 연관 모듈 |
| `HF4` | `frontend/haccp-web/src/api/authApi.ts` | API 레이어 |
| `HF16` | `frontend/haccp-web/src/api/menuApi.ts` | API 레이어 |
| `HF17` | `frontend/haccp-web/src/api/codeApi.ts` | API 레이어 |
| `HF18` | `frontend/haccp-web/src/api/prefApi.ts` | API 레이어 |
| `HF19` | `frontend/haccp-web/src/api/viewLogApi.ts` | API 레이어 |
| `HF29` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
| `HF30` | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 연관 모듈 |
| `HF31` | `frontend/haccp-web/src/config/envConfig.ts` | 전역 설정 |
| `HF32` | `frontend/haccp-web/src/types/common.ts` | 공통 모듈 |
| `HF35` | `frontend/haccp-web/src/lib/datetime.ts` | 공통 모듈 |
| `HF36` | `frontend/haccp-web/src/lib/cn.ts` | 공통 모듈 |
| `HF37` | `frontend/haccp-web/src/lib/buttonVariants.ts` | 공통 모듈 |
| `HF38` | `frontend/haccp-web/src/lib/icons.tsx` | 공통 모듈 |
| `HF39` | `frontend/haccp-web/src/hooks/useAsyncAction.ts` | 커스텀 훅 |
| `HF41` | `frontend/haccp-web/src/components/layout/SearchArea.tsx` | 연관 — useEditableRows / pageCommands(search) |
| `HF49` | `frontend/haccp-web/src/shell/dialog.tsx` | 연관 — 셸 |
| `HF51` | `frontend/haccp-web/src/pages/tsk/TodayTasksPage.tsx` | 연관 모듈 |
| `HF52` | `frontend/haccp-web/src/components/layout/SearchArea.tsx` | 연관 — useEditableRows / pageCommands(search) |
| `HF54` | `frontend/haccp-web/src/shell/errors.ts` | 셸 인프라 |
| `HF55` | `frontend/haccp-web/src/shell/messages.ts` | 셸 인프라 |
| `HF56` | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxPage.tsx` | 연관 모듈 |
| `HF62` | `frontend/haccp-web/src/shell/HomeView.tsx` | 홈 화면 |
| `HF64` | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 연관 모듈 |
| `HF66` | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 연관 모듈 |
| `HF68` | `frontend/haccp-web/src/shell/tabRoute.ts` | 셸 인프라 |
| `HF70` | `frontend/haccp-web/src/shell/useViewLog.ts` | 셸 인프라 |
| `HF74` | `frontend/haccp-web/src/main.tsx` | 연관 모듈 |
| `HF76` | `frontend/haccp-web/src/shell/useSection.ts` | 셸 인프라 — mes-web useSection와 동일 계약 |
| `HF81` | `frontend/haccp-web/src/components/form/DocFormLayout.tsx` | 연관 모듈 |
| `HF82` | `frontend/haccp-web/src/api/documentApi.ts` | API 레이어 |
| `HF83` | `frontend/haccp-web/src/components/form/DocFormSearchToolbar.tsx` | 연관 모듈 |
| `HF84` | `frontend/haccp-web/src/lib/rhwpStudio.ts` | HWP 문서 편집 연관 |
| `HF85` | `frontend/haccp-web/src/components/form/DocFormSearchToolbar.tsx` | 연관 모듈 |
| `HF86` | `frontend/haccp-web/src/api/sys/approvalLineApi.ts` | 결재선 관리 API |
| `HF87` | `frontend/haccp-web/src/api/taskWorkflowApi.ts` | 워크플로 화면 API |
| `HF88` | `frontend/haccp-web/src/api/taskWorkflowApi.ts` | 연관 모듈 |
| `HF89` | `frontend/haccp-web/src/api/taskWorkflowApi.ts` | 연관 모듈 |
| `HF90` | `frontend/haccp-web/src/hooks/useGridAccess.ts` | 연관 모듈 |
| `HF92` | `frontend/haccp-web/src/api/sys/auditLogApi.ts` | 변경 감사 로그 API |
| `HF93` | `frontend/haccp-web/src/components/layout/pageClasses.ts` | UI 컴포넌트 — mes-web pageClasses와 동일 계약 |
| `HF95` | `frontend/haccp-web/src/components/layout/SearchArea.tsx` | UI 컴포넌트 — mes-web SearchArea와 동일 계약 |
| `HF96` | `frontend/haccp-web/src/hooks/useGridAccess.ts` | 그리드 접근 훅 |
| `HF97` | `frontend/haccp-web/src/pages/sys/code/user/UserManagementPage.tsx` | 연관 모듈 |
| `HF98` | `frontend/haccp-web/src/pages/sys/code/commoncode/CommonCodeRule.ts` | 공통코드 그리드 규칙 |
| `HF99` | `frontend/haccp-web/src/components/common/modal/CodeLookupModal.tsx` | 코드 조회 팝업 |
| `HF102` | `frontend/haccp-web/src/components/document/DocumentApprovalToolbar.tsx` | 연관 모듈 |
| `HF103` | `frontend/haccp-web/src/components/document/ApprovalDocumentPreview.tsx` | 연관 모듈 |
| `HF112` | `frontend/haccp-web/src/components/ui/Input.tsx` | UI 컴포넌트 |
| `HF113` | `frontend/haccp-web/src/components/ui/MesButton.tsx` | UI 컴포넌트 |
| `HF114` | `frontend/haccp-web/src/main.tsx` | 연관 모듈 |
| `HF115` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 로그인 화면 |
| `HF119` | `frontend/haccp-web/src/components/form/DocFormLayout.tsx` | DB형 문서 레이아웃 |
| `HF120` | `frontend/haccp-web/src/components/form/DocCell.tsx` | 연관 모듈 |
| `HF121` | `frontend/haccp-web/src/lib/camelKeys.ts` | API 키 정규화 |
| `HF122` | `frontend/haccp-web/src/components/form/DocCell.tsx` | 문서 셀 입력 |
| `HF123` | `frontend/haccp-web/src/api/docs/docCycleApi.ts` | 연관 모듈 |
| `HF124` | `frontend/haccp-web/src/api/docs/docCycleApi.ts` | 문서주기관리 API |
| `HF130` | `frontend/haccp-web/src/api/docs/htmlFormApi.ts` | HTML양식 API |
| `HF131` | `frontend/haccp-web/src/pages/docs/html-form/ccpverifytemplate/CcpChkPaper.tsx` | CCP 검증점검 지면 |
| `HF132` | `frontend/haccp-web/src/pages/docs/html-form/ccppkgtemplate/CcpPkgPaper.tsx` | CCP-1B 포장일지 지면 |
| `HF133` | `frontend/haccp-web/src/pages/docs/html-form/ccphtgtemplate/CcpHtgPaper.tsx` | CCP-2B 가열일지 지면 |
| `HF134` | `frontend/haccp-web/src/pages/docs/html-form/ccpmtltemplate/CcpMtlPaper.tsx` | CCP-3P 금속검출일지 지면 |
| `HF135` | `frontend/haccp-web/src/components/form/htmlFormPaperShared.tsx` | HTML 양식 지면 공통 |
| `HF160` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
| `HF161` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
| `HF162` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
| `HF169` | `frontend/haccp-web/src/components/ui/HaccpLogo.tsx` | UI 컴포넌트 |
| `HF172` | `frontend/haccp-web/src/api/draft/htmlFormDraftTypes.ts` | 양식 작성 API 계약 |
| `HF173` | `frontend/haccp-web/src/components/document/HtmlDocumentPreview.tsx` | 연관 모듈 |
| `HF174` | `frontend/haccp-web/src/pages/draft/HtmlFormLookupModal.tsx` | 양식 선택 팝업 |
| `HF175` | `frontend/haccp-web/src/api/draft/ccpVerifyDraftApi.ts` | CCP 검증점검 작성 API |
| `HF176` | `frontend/haccp-web/src/pages/draft/html/CcpVerifyDraftPage.tsx` | CCP 검증점검 작성 화면 |
| `HF177` | `frontend/haccp-web/src/api/draft/ccpMonitoringDraftApi.ts` | CCP 모니터링 작성 API |
| `HF178` | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpPkgDraftPage.tsx` | CCP 포장 작성 화면 |
| `HF179` | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpHtgDraftPage.tsx` | CCP 가열 작성 화면 |
| `HF180` | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpMtlDraftPage.tsx` | CCP 금속검출 작성 화면 |
| `HF181` | `frontend/haccp-web/src/pages/draft/HtmlFormDeviationSignal.tsx` | 이탈·개선조치 시그널 |
| `HF182` | `frontend/haccp-web/src/api/draft/hwpDraftApi.ts` | HWP 작성 API |
| `HF183` | `frontend/haccp-web/src/pages/draft/HwpTaskLookupModal.tsx` | HWP 오늘 할일 팝업 |
| `HF184` | `frontend/haccp-web/src/components/document/ApprovalDocumentPreview.tsx` | 결재 문서 미리보기 |
| `HF185` | `frontend/haccp-web/src/pages/flow/appr/attach/ApprovalAttachPage.tsx` | 결재 첨부 화면 |
| `HF200` | `frontend/haccp-web/src/shell/gridRules/gridSave.ts` | 편집 그리드 저장 공통 |

## 백엔드 (HB) — 81개

| 태그 | 파일 | 무엇 |
|---|---|---|
| `HB1` | `backend/haccp-api/src/main/java/com/haccp/HaccpApiApplication.java` | Spring Boot 진입 |
| `HB2` | `backend/haccp-api/src/main/java/com/haccp/HaccpApiApplication.java` | 연관 — application.yml |
| `HB3` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | Spring 설정 |
| `HB4` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthController.java` | 연관 모듈 |
| `HB5` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | 연관 모듈 |
| `HB6` | `backend/haccp-api/src/main/java/com/haccp/common/exception/BizException.java` | 연관 모듈 |
| `HB7` | `backend/haccp-api/src/main/java/com/haccp/common/exception/GlobalExceptionHandler.java` | 연관 모듈 |
| `HB8` | `backend/haccp-api/src/main/java/com/haccp/common/exception/BizException.java` | 예외 처리 |
| `HB9` | `backend/haccp-api/src/main/java/com/haccp/common/response/CommonResponse.java` | common 모듈 |
| `HB10` | `backend/haccp-api/src/main/java/com/haccp/common/response/ErrorResponse.java` | common 모듈 |
| `HB11` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | 연관 모듈 |
| `HB12` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | 연관 모듈 |
| `HB13` | `backend/haccp-api/src/main/java/com/haccp/common/context/RequestMeta.java` | common 모듈 |
| `HB19` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthController.java` | REST Controller |
| `HB20` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthController.java` | 연관 모듈 |
| `HB23` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/LoginRequest.java` | auth DTO |
| `HB24` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/UserLoginRow.java` | auth DTO |
| `HB25` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/ScreenAuthRow.java` | auth DTO |
| `HB26` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/LoginResponse.java` | auth DTO |
| `HB27` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthMapper.java` | MyBatis 매퍼 |
| `HB28` | `backend/haccp-api/src/main/resources/mapper/auth/AuthMapper.xml` | MyBatis XML |
| `HB30` | `backend/haccp-api/src/main/java/com/haccp/menu/dto/MenuRow.java` | menu DTO |
| `HB31` | `backend/haccp-api/src/main/java/com/haccp/menu/MenuController.java` | 연관 모듈 |
| `HB32` | `backend/haccp-api/src/main/java/com/haccp/menu/MenuController.java` | 연관 모듈 |
| `HB33` | `backend/haccp-api/src/main/java/com/haccp/menu/MenuController.java` | REST Controller |
| `HB34` | `backend/haccp-api/src/main/java/com/haccp/code/dto/CodeRow.java` | code DTO |
| `HB35` | `backend/haccp-api/src/main/java/com/haccp/code/CodeController.java` | 연관 모듈 |
| `HB36` | `backend/haccp-api/src/main/java/com/haccp/code/CodeController.java` | 연관 모듈 |
| `HB37` | `backend/haccp-api/src/main/java/com/haccp/code/CodeController.java` | REST Controller |
| `HB38` | `backend/haccp-api/src/main/java/com/haccp/pref/dto/GridPrefRow.java` | pref DTO |
| `HB39` | `backend/haccp-api/src/main/java/com/haccp/pref/dto/GridPrefSaveRequest.java` | pref DTO |
| `HB40` | `backend/haccp-api/src/main/java/com/haccp/pref/PrefController.java` | 연관 모듈 |
| `HB41` | `backend/haccp-api/src/main/java/com/haccp/pref/PrefController.java` | 연관 모듈 |
| `HB42` | `backend/haccp-api/src/main/java/com/haccp/pref/PrefController.java` | REST Controller |
| `HB43` | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatDailyJob.java` | 연관 모듈 |
| `HB44` | `backend/haccp-api/src/main/java/com/haccp/log/LogMapper.java` | MyBatis 매퍼 |
| `HB45` | `backend/haccp-api/src/main/java/com/haccp/log/ViewLogController.java` | 연관 모듈 |
| `HB46` | `backend/haccp-api/src/main/java/com/haccp/log/ViewLogController.java` | REST Controller |
| `HB47` | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatDailyJob.java` | 화면 이용 통계 집계 |
| `HB50` | `backend/haccp-api/src/main/java/com/haccp/common/validation/DeleteBlocker.java` | common 모듈 |
| `HB51` | `backend/haccp-api/src/main/java/com/haccp/common/validation/DeleteBlocker.java` | 연관 모듈 |
| `HB62` | `backend/haccp-api/src/main/java/com/haccp/flow/ca/dto/DocCorrectiveDto.java` | ccp DTO |
| `HB63` | `backend/haccp-api/src/main/java/com/haccp/flow/ca/DocCorrectiveMapper.java` | Mapper |
| `HB64` | `backend/haccp-api/src/main/java/com/haccp/flow/ca/DocCorrectiveSupport.java` | 문서 푸터 지원 |
| `HB72` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentApprovalRequest.java` | 연관 모듈 |
| `HB80` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | 연관 모듈 |
| `HB81` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | 연관 모듈 |
| `HB82` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentFileStorage.java` | 연관 모듈 |
| `HB83` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentMapper.java` | MyBatis 매퍼 |
| `HB84` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentMapper.java` | 연관 모듈 |
| `HB85` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentFileStorage.java` | doc 파일 저장 |
| `HB86` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | 연관 모듈 |
| `HB87` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | REST Controller |
| `HB88` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateResponse.java` | 템플릿 DTO |
| `HB89` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateRow.java` | 연관 모듈 |
| `HB90` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateResponse.java` | 연관 모듈 |
| `HB91` | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateController.java` | 템플릿 REST Controller |
| `HB92` | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateController.java` | 연관 모듈 |
| `HB93` | `backend/haccp-api/src/main/java/com/haccp/docs/templates/RhwpCliClient.java` | rhwp CLI PDF 변환 |
| `HB94` | `backend/haccp-api/src/main/java/com/haccp/docs/sch/CycleScheduleGenerator.java` | 연관 모듈 |
| `HB95` | `frontend/haccp-web/src/pages/tsk/TodayTasksPage.tsx` | 연관 모듈 |
| `HB96` | `backend/haccp-api/src/main/java/com/haccp/tsk/DailyTaskGenerationJob.java` | 워크플로 일정 생성 |
| `HB98` | `backend/haccp-api/src/main/java/com/haccp/docs/sch/CycleScheduleGenerator.java` | 문서주기 예정일 생성기 |
| `HB99` | `backend/haccp-api/src/main/java/com/haccp/docs/sch/CycleScheduleGenerator.java` | 연관 모듈 |
| `HB123` | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateController.java` | 사용양식 REST Controller |
| `HB130` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/htmltemplate/HtmlTemplateController.java` | HTML양식 원본 Controller |
| `HB131` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.java` | CCP 검증점검 양식 Mapper |
| `HB132` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.java` | CCP-1B 포장일지 양식 Mapper |
| `HB133` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.java` | CCP-2B 가열일지 양식 Mapper |
| `HB134` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.java` | CCP-3P 금속검출일지 양식 Mapper |
| `HB135` | `backend/haccp-api/src/main/java/com/haccp/draft/DraftSupport.java` | 양식 작성 공용 유틸 |
| `HB136` | `backend/haccp-api/src/main/java/com/haccp/draft/html/HygProcessDraftController.java` | 위생공정 작성 Controller |
| `HB137` | `backend/haccp-api/src/main/java/com/haccp/draft/html/CcpVerifyDraftMapper.java` | CCP 검증점검 작성 Mapper |
| `HB138` | `backend/haccp-api/src/main/java/com/haccp/draft/html/CcpVerifyDraftController.java` | CCP 검증점검 작성 Controller |
| `HB139` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpLogDraftMapper.java` | CCP 모니터링 작성 Mapper |
| `HB140` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpLogDraftControllerBase.java` | CCP 모니터링 작성 공통 Controller |
| `HB141` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpPkgDraftController.java` | CcpPkgDraftController — CCP 포장(CCP-1B) 모니터링일지 작성 REST |
| `HB142` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpHtgDraftController.java` | CcpHtgDraftController — CCP 가열(CCP-2B) 모니터링일지 작성 REST |
| `HB143` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpMtlDraftController.java` | CCP 금속검출 작성 Controller |
| `HB144` | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftTaskRow.java` | HWP 작성 DTO |
| `HB145` | `backend/haccp-api/src/main/java/com/haccp/common/auth/ScreenAuthAction.java` | 화면 권한 인터셉터 |
