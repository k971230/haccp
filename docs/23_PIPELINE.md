# HACCP PIPELINE 색인 (HF / HB)

> 정본: 이 파일. 코드의 `PIPELINE[HFn]` / `PIPELINE[HBn]` 태그와 대응한다.
> 업무 서사·시퀀스 다이어그램은 [`15_HACCP_FE_BE_통합_상세스펙.md`](15_HACCP_FE_BE_통합_상세스펙.md)다. 여기서는 태그 → 파일만 적는다.
>
> 작성일: 2026-08-21 · 코드 harvest. **번호를 재채번하지 않는다.**

## 채번 규칙

- 표에 없는 새 모듈만 다음 빈 번호를 쓰고 코드 헤더에 태그를 단다.
- 같은 번호가 여러 파일에 있으면 **클러스터**다. 고유 ID가 아니다. 충돌 절을 본다.
- MES 잔존 `PIPELINE[Fn]`(접두 F, HF 아님)은 맨 아래. 새 코드에 `F` 접두를 쓰지 않는다.
- 루트 `README.md`에는 전수 표를 두지 않는다. 사용법만 두고 이 파일을 가리킨다.

## 사람이 체인을 읽으려면

루트 README E2E → 이 파일(태그 위치) → docs/15(유형별 이야기) → 도메인 README.

## FE 주요 대역 (안내)

| 대역 | 뜻 |
|---|---|
| HF1–HF2 | 진입 `main.tsx` · `AppRoutes` |
| HF3 | HTTP 클라이언트 |
| HF29–HF31 | authStore · envConfig |
| HF49 | HaccpShell · ShellTabBar |
| HF51 | screenRegistry |
| HF68 | tabRoute |
| HF80–HF85 | CCP·문서 API/화면 |
| HF98–HF99 | sys 화면(클러스터) |
| HF120–HF135 | DocForm · HTML 양식 |
| HF172–HF180 | 양식 작성(draft) — HYG·CCP·CCP 모니터링 |

## BE 주요 대역 (안내)

| 대역 | 뜻 |
|---|---|
| HB1–HB13 | 부트 · JWT · 예외 · LoginUser |
| HB20–HB27 | 인증 Auth* |
| HB51 | DeleteValidation |
| HB63–HB70 | CCP 냉장 |
| HB83–HB91 | 문서·템플릿 |
| HB92–HB94 | sys Mapper/Service 클러스터 |
| HB123–HB134 | 사용양식 · HTML 양식 |
| HB135–HB143 | 양식 작성(draft) — HYG·CCP·CCP 모니터링 |
| HB144 | HWP 작성(draft hwp-write) |
| HB145 | 화면 권한 인터셉터 |

## FE (`PIPELINE[HFn]`)

| 태그 | 파일 수 | 파일 |
|---|---|---|
| `HF1` | 1 | `fe:main.tsx` |
| `HF2` | 1 | `fe:routes/AppRoutes.tsx` |
| `HF3` | 4 | `fe:api/ccpColdApi.ts`<br>`fe:api/documentApi.ts`<br>`fe:api/http.ts`<br>`fe:config/envConfig.ts` |
| `HF4` | 1 | `fe:api/authApi.ts` |
| `HF16` | 1 | `fe:api/menuApi.ts` |
| `HF17` | 2 | `fe:api/codeApi.ts`<br>`fe:hooks/useCommonCodes.ts` |
| `HF18` | 1 | `fe:api/prefApi.ts` |
| `HF19` | 1 | `fe:api/viewLogApi.ts` |
| `HF29` | 1 | `fe:stores/authStore.ts` |
| `HF30` | 2 | `fe:stores/modalStore.ts`<br>`fe:stores/tabStore.ts` |
| `HF31` | 1 | `fe:config/envConfig.ts` |
| `HF32` | 1 | `fe:types/common.ts` |
| `HF35` | 1 | `fe:lib/datetime.ts` |
| `HF36` | 1 | `fe:lib/cn.ts` |
| `HF37` | 1 | `fe:lib/buttonVariants.ts` |
| `HF38` | 1 | `fe:lib/icons.tsx` |
| `HF39` | 1 | `fe:hooks/useAsyncAction.ts` |
| `HF49` | 9 | `fe:shell/dialog.tsx`<br>`fe:shell/errors.ts`<br>`fe:shell/HaccpShell.tsx`<br>`fe:shell/messages.ts`<br>`fe:shell/screenRegistry.tsx`<br>`fe:shell/ShellFooter.tsx`<br>`fe:shell/ShellTabBar.tsx`<br>`fe:shell/tabRoute.ts`<br>`fe:stores/tabStore.ts` |
| `HF51` | 1 | `fe:shell/screenRegistry.tsx` |
| `HF54` | 1 | `fe:shell/errors.ts` |
| `HF55` | 1 | `fe:shell/messages.ts` |
| `HF56` | 1 | `fe:shell/dialog.tsx` |
| `HF62` | 1 | `fe:shell/HomeView.tsx` |
| `HF64` | 1 | `fe:shell/ShellFooter.tsx` |
| `HF66` | 1 | `fe:shell/SideMenu.tsx` |
| `HF68` | 1 | `fe:shell/tabRoute.ts` |
| `HF70` | 1 | `fe:shell/useViewLog.ts` |
| `HF74` | 5 | `fe:shell/authCrossTab.ts`<br>`fe:shell/authPaths.ts`<br>`fe:shell/authSession.ts`<br>`fe:shell/useActiveGrid.ts`<br>`fe:shell/mesSec.ts` |
| `HF76` | 1 | `fe:shell/useSection.ts` |
| `HF80` | 1 | `fe:api/ccpColdApi.ts` |
| `HF81` | 1 | `fe:pages/docs/ccp/ColdMonitorPage.tsx` |
| `HF82` | 4 | `fe:api/documentApi.ts`<br>`fe:api/hygieneApi.ts`<br>`fe:hooks/useDocIdxQuery.ts`<br>`fe:lib/documentNav.ts` |
| `HF83` | 3 | `fe:pages/flow/box/documentbox/DocumentBoxPage.tsx`<br>`fe:pages/flow/box/documentbox/DocumentBoxRule.ts`<br>`fe:pages/docs/prp/HygieneCheckPage.tsx` |
| `HF84` | 6 | `fe:api/bizOpsApi.ts`<br>`fe:api/ccpFormsApi.ts`<br>`fe:api/masterApi.ts`<br>`fe:lib/rhwpStudio.ts`<br>`fe:pages/docs/hwp/HwpDocumentEditorPage.tsx`<br>`fe:pages/docs/hwp/HwpDocumentEditorRule.ts` |
| `HF85` | 3 | `fe:pages/bas/master/MasterDataPage.tsx`<br>`fe:pages/docs/ccp/CcpFormPage.tsx`<br>`fe:pages/docs/prp/BizOpsFormPage.tsx` |
| `HF86` | 2 | `fe:api/workflowApi.ts`<br>`fe:api/sys/approvalLineApi.ts` |
| `HF87` | 3 | `fe:api/taskWorkflowApi.ts`<br>`fe:pages/sys/code/approvalline/ApprovalLineManagementPage.tsx`<br>`fe:pages/sys/code/approvalline/ApprovalLineManagementRule.ts` |
| `HF88` | 3 | `fe:lib/docStatus.ts`<br>`fe:pages/tsk/TodayTasksPage.tsx`<br>`fe:pages/tsk/TodayTasksRule.ts` |
| `HF89` | 4 | `fe:pages/flow/ca/corrective/CorrectiveActionManagementPage.tsx`<br>`fe:pages/flow/ca/corrective/CorrectiveActionManagementRule.ts`<br>`fe:pages/docs/sch/ScheduleCycleManagementPage.tsx`<br>`fe:pages/docs/sch/ScheduleCycleManagementRule.ts` |
| `HF92` | 13 | `fe:api/sys/auditLogApi.ts`<br>`fe:api/sys/commonCodeApi.ts`<br>`fe:api/sys/departmentApi.ts`<br>`fe:api/sys/loginHistoryApi.ts`<br>`fe:api/sys/menuApi.ts`<br>`fe:api/sys/roleApi.ts`<br>`fe:api/sys/screenUsageApi.ts`<br>`fe:api/sys/sysTypes.ts`<br>`fe:api/sys/userApi.ts`<br>`fe:components/layout/PageCard.tsx`<br>`fe:components/layout/ResizableSplit.tsx`<br>`fe:components/layout/TreePanelSearch.tsx`<br>`fe:lib/treeFilter.ts` |
| `HF93` | 1 | `fe:components/layout/pageClasses.ts` |
| `HF94` | 1 | `fe:api/ccpGenericApi.ts` |
| `HF95` | 2 | `fe:components/layout/SearchArea.tsx`<br>`fe:pages/docs/ccp/CcpGenericMonitorPage.tsx` |
| `HF96` | 1 | `fe:hooks/useGridAccess.ts` |
| `HF97` | 1 | `fe:shell/resolveDelete.ts` |
| `HF98` | 8 | `fe:pages/sys/logs/auditlog/AuditLogRule.ts`<br>`fe:pages/sys/code/commoncode/CommonCodeRule.ts`<br>`fe:pages/sys/code/department/DepartmentManagementRule.ts`<br>`fe:pages/sys/logs/loginhistory/LoginHistoryRule.ts`<br>`fe:pages/sys/code/menu/MenuManagementRule.ts`<br>`fe:pages/sys/code/role/RoleManagementRule.ts`<br>`fe:pages/sys/logs/screenusage/ScreenUsageStatisticsRule.ts`<br>`fe:pages/sys/code/user/UserManagementRule.ts` |
| `HF99` | 15 | `fe:components/common/modal/CodeLookupModal.tsx`<br>`fe:components/common/modal/GlobalModal.tsx`<br>`fe:components/common/modal/modalTypes.ts`<br>`fe:components/common/modal/UserSignModal.tsx`<br>`fe:components/layout/LogPageShell.tsx`<br>`fe:lib/yn.ts`<br>`fe:pages/sys/logs/auditlog/AuditLogPage.tsx`<br>`fe:pages/sys/code/commoncode/CommonCodePage.tsx`<br>`fe:pages/sys/code/department/DepartmentManagementPage.tsx`<br>`fe:pages/sys/logs/loginhistory/LoginHistoryPage.tsx`<br>`fe:pages/sys/code/menu/MenuManagementPage.tsx`<br>`fe:pages/sys/code/role/RoleManagementPage.tsx`<br>`fe:pages/sys/logs/screenusage/ScreenUsageStatisticsPage.tsx`<br>`fe:pages/sys/code/user/UserManagementPage.tsx`<br>`fe:stores/modalStore.ts` |
| `HF100` | 1 | `fe:pages/bas/master/MasterDataPage.rules.ts` |
| `HF102` | 2 | `fe:components/ui/SysYnBadge.tsx`<br>`fe:hooks/useCommonCodes.ts` |
| `HF103` | 1 | `fe:components/document/DocumentApprovalToolbar.tsx` |
| `HF112` | 1 | `fe:components/ui/Input.tsx` |
| `HF113` | 1 | `fe:components/ui/MesButton.tsx` |
| `HF115` | 1 | `fe:pages/auth/LoginPage.tsx` |
| `HF119` | 2 | `fe:components/form/DocFormLayout.tsx`<br>`fe:components/form/DocSummaryPanel.tsx` |
| `HF120` | 8 | `fe:components/form/DocApprovalStamp.tsx`<br>`fe:components/form/DocCell.tsx`<br>`fe:components/form/DocDeviationFooter.tsx`<br>`fe:components/form/DocFormMeta.tsx`<br>`fe:components/form/DocFormSearchToolbar.tsx`<br>`fe:components/form/DocPaper.tsx`<br>`fe:components/form/DocRowToolbar.tsx`<br>`fe:hooks/useDocFormSession.ts` |
| `HF121` | 2 | `fe:components/form/DocApprovalStamp.tsx`<br>`fe:lib/camelKeys.ts` |
| `HF122` | 4 | `fe:components/form/DocCell.tsx`<br>`fe:lib/docDateTime.ts`<br>`fe:pages/flow/box/legalupload/LegalDocumentUploadPage.tsx`<br>`fe:pages/flow/box/legalupload/LegalDocumentUploadRule.ts` |
| `HF123` | 7 | `fe:api/docs/hwpTemplateApi.ts`<br>`fe:components/form/DocFormMeta.tsx`<br>`fe:components/form/DocSummaryPanel.tsx`<br>`fe:components/ui/SysYnBadge.tsx`<br>`fe:pages/docs/hwp/HwpTemplateFileHistModal.tsx`<br>`fe:pages/docs/hwp/HwpTemplateManagementPage.tsx`<br>`fe:pages/docs/hwp/HwpTemplateManagementRule.ts` |
| `HF124` | 4 | `fe:api/equipmentHistApi.ts`<br>`fe:api/healthCertApi.ts`<br>`fe:api/docs/docCycleApi.ts`<br>`fe:components/form/DocDeviationFooter.tsx` |
| `HF125` | 3 | `fe:components/form/DocRowToolbar.tsx`<br>`fe:pages/docs/prp/EquipmentHistoryPage.tsx`<br>`fe:pages/docs/prp/HealthCertPage.tsx` |
| `HF126` | 2 | `fe:api/pestDeviceHistApi.ts`<br>`fe:pages/docs/prp/PestDeviceHistoryPage.tsx` |
| `HF130` | 6 | `fe:api/docs/htmlFormApi.ts`<br>`fe:pages/docs/html/HtmlFormTemplatePage.tsx`<br>`fe:pages/docs/html/htmlFormTemplateShared.ts`<br>`fe:pages/docs/html/htmltemplate/HtmlTemplatePage.tsx`<br>`fe:pages/docs/html/htmltemplate/HtmlTemplateRule.ts`<br>`fe:pages/docs/html/htmltemplate/HygPrcPaper.tsx` |
| `HF131` | 5 | `fe:pages/docs/html/ccpverifytemplate/CcpChkPaper.tsx`<br>`fe:pages/docs/html/ccpverifytemplate/CcpVerifyTemplatePage.tsx`<br>`fe:pages/docs/html/ccpverifytemplate/CcpVerifyTemplateRule.ts`<br>`fe:pages/docs/html/hygprocess/HygProcessPage.tsx`<br>`fe:pages/docs/html/hygprocess/HygProcessRule.ts` |
| `HF132` | 3 | `fe:pages/docs/html/ccppkgtemplate/CcpPkgPaper.tsx`<br>`fe:pages/docs/html/ccppkgtemplate/CcpPkgTemplatePage.tsx`<br>`fe:pages/docs/html/ccppkgtemplate/CcpPkgTemplateRule.ts` |
| `HF133` | 3 | `fe:pages/docs/html/ccphtgtemplate/CcpHtgPaper.tsx`<br>`fe:pages/docs/html/ccphtgtemplate/CcpHtgTemplatePage.tsx`<br>`fe:pages/docs/html/ccphtgtemplate/CcpHtgTemplateRule.ts` |
| `HF134` | 3 | `fe:pages/docs/html/ccpmtltemplate/CcpMtlPaper.tsx`<br>`fe:pages/docs/html/ccpmtltemplate/CcpMtlTemplatePage.tsx`<br>`fe:pages/docs/html/ccpmtltemplate/CcpMtlTemplateRule.ts` |
| `HF135` | 1 | `fe:components/form/htmlFormPaperShared.tsx` |
| `HF160` | 1 | `fe:shell/authKeys.ts` |
| `HF161` | 2 | `fe:shell/authPaths.ts`<br>`fe:shell/authSession.ts` |
| `HF162` | 1 | `fe:shell/loginPrefs.ts` |
| `HF169` | 1 | `fe:components/ui/HaccpLogo.tsx` |
| `HF171` | 1 | `fe:lib/sanitize.ts` |
| `HF172` | 4 | `fe:api/draft/htmlFormDraftTypes.ts`<br>`fe:api/draft/hygProcessDraftApi.ts`<br>`fe:pages/draft/htmlFormDraftShared.ts`<br>`fe:pages/draft/hyg/HygProcessDraftRule.ts` |
| `HF173` | 2 | `fe:pages/draft/HtmlFormDraftPage.tsx`<br>`fe:pages/draft/hyg/HygProcessDraftPage.tsx` |
| `HF174` | 1 | `fe:pages/draft/HtmlFormLookupModal.tsx` |
| `HF175` | 2 | `fe:api/draft/ccpVerifyDraftApi.ts`<br>`fe:pages/draft/ccp/CcpVerifyDraftRule.ts` |
| `HF176` | 1 | `fe:pages/draft/ccp/CcpVerifyDraftPage.tsx` |
| `HF177` | 2 | `fe:api/draft/ccpMonitoringDraftApi.ts`<br>`fe:pages/draft/htmlFormLogRows.test.ts` |
| `HF178` | 2 | `fe:pages/draft/ccp-monitoring/CcpPkgDraftPage.tsx`<br>`fe:pages/draft/ccp-monitoring/CcpPkgDraftRule.ts` |
| `HF179` | 2 | `fe:pages/draft/ccp-monitoring/CcpHtgDraftPage.tsx`<br>`fe:pages/draft/ccp-monitoring/CcpHtgDraftRule.ts` |
| `HF180` | 2 | `fe:pages/draft/ccp-monitoring/CcpMtlDraftPage.tsx`<br>`fe:pages/draft/ccp-monitoring/CcpMtlDraftRule.ts` |

## BE (`PIPELINE[HBn]`)

| 태그 | 파일 수 | 파일 |
|---|---|---|
| `HB1` | 1 | `be:HaccpApiApplication.java` |
| `HB2` | 1 | `be:HaccpApiApplication.java` |
| `HB3` | 1 | `be:common/config/JwtFilter.java` |
| `HB4` | 1 | `be:common/config/JwtProvider.java` |
| `HB5` | 1 | `be:common/config/WebConfig.java` |
| `HB6` | 4 | `be:common/exception/BizException.java`<br>`be:common/exception/GlobalExceptionHandler.java`<br>`be:common/exception/NotFoundException.java`<br>`be:common/exception/SqlUserMessage.java` |
| `HB7` | 2 | `be:common/exception/GlobalExceptionHandler.java`<br>`be:common/exception/SqlUserMessage.java` |
| `HB8` | 2 | `be:common/exception/BizException.java`<br>`be:common/exception/NotFoundException.java` |
| `HB9` | 1 | `be:common/response/CommonResponse.java` |
| `HB10` | 1 | `be:common/response/ErrorResponse.java` |
| `HB11` | 1 | `be:common/context/LoginUser.java` |
| `HB12` | 1 | `be:common/context/LoginUserContext.java` |
| `HB13` | 1 | `be:common/context/RequestMeta.java` |
| `HB19` | 1 | `be:auth/AuthController.java` |
| `HB20` | 1 | `be:auth/AuthService.java` |
| `HB23` | 1 | `be:auth/dto/LoginRequest.java` |
| `HB24` | 1 | `be:auth/dto/UserLoginRow.java` |
| `HB25` | 1 | `be:auth/dto/ScreenAuthRow.java` |
| `HB26` | 1 | `be:auth/dto/LoginResponse.java` |
| `HB27` | 1 | `be:auth/AuthMapper.java` |
| `HB28` | 1 | `xml:auth/AuthMapper.xml` |
| `HB30` | 1 | `be:menu/dto/MenuRow.java` |
| `HB31` | 1 | `be:menu/MenuMapper.java` |
| `HB32` | 1 | `xml:menu/MenuMapper.xml` |
| `HB33` | 1 | `be:menu/MenuController.java` |
| `HB34` | 1 | `be:code/dto/CodeRow.java` |
| `HB35` | 1 | `be:code/CodeMapper.java` |
| `HB36` | 1 | `xml:code/CodeMapper.xml` |
| `HB37` | 1 | `be:code/CodeController.java` |
| `HB38` | 1 | `be:pref/dto/GridPrefRow.java` |
| `HB39` | 1 | `be:pref/dto/GridPrefSaveRequest.java` |
| `HB40` | 1 | `be:pref/PrefMapper.java` |
| `HB41` | 1 | `xml:pref/PrefMapper.xml` |
| `HB42` | 1 | `be:pref/PrefController.java` |
| `HB43` | 1 | `be:log/dto/ViewLogItem.java` |
| `HB44` | 1 | `be:log/LogMapper.java` |
| `HB45` | 1 | `xml:log/LogMapper.xml` |
| `HB46` | 1 | `be:log/ViewLogController.java` |
| `HB47` | 2 | `be:log/ViewStatDailyJob.java`<br>`be:log/ViewStatService.java` |
| `HB50` | 1 | `be:common/validation/DeleteBlocker.java` |
| `HB51` | 3 | `be:common/validation/DeleteBlocker.java`<br>`be:common/validation/DeleteValidation.java`<br>`be:docs/document/dto/DocumentDeleteItem.java` |
| `HB60` | 1 | `be:docs/ccp/dto/StorageRow.java` |
| `HB61` | 1 | `be:docs/ccp/dto/CcpLimitRow.java` |
| `HB62` | 2 | `be:docs/ccp/dto/ColdMonitorListRow.java`<br>`be:docs/ccp/dto/DocCorrectiveDto.java` |
| `HB63` | 2 | `be:docs/ccp/dto/ColdMonitorHeader.java`<br>`be:flow/ca/DocCorrectiveMapper.java` |
| `HB64` | 3 | `be:docs/ccp/dto/ColdMonitorTempCell.java`<br>`be:docs/ccp/dto/ColdMonitorTempJoinRow.java`<br>`be:flow/ca/DocCorrectiveSupport.java` |
| `HB65` | 1 | `be:docs/ccp/dto/ColdMonitorRowDto.java` |
| `HB66` | 1 | `be:docs/ccp/dto/ColdMonitorDetail.java` |
| `HB67` | 1 | `be:docs/ccp/dto/ColdMonitorSaveRequest.java` |
| `HB68` | 1 | `be:docs/ccp/dto/ColdMonitorDeleteItem.java` |
| `HB69` | 1 | `be:docs/ccp/CcpColdMapper.java` |
| `HB70` | 2 | `be:docs/ccp/CcpColdMapper.java`<br>`xml:docs/ccp/CcpColdMapper.xml` |
| `HB71` | 1 | `be:docs/ccp/CcpColdService.java` |
| `HB72` | 2 | `be:docs/ccp/CcpColdController.java`<br>`be:docs/document/dto/DocumentApprovalRequest.java` |
| `HB73` | 1 | `be:bas/master/MasterType.java` |
| `HB74` | 1 | `be:bas/master/MasterService.java` |
| `HB75` | 2 | `be:bas/master/MasterMapper.java`<br>`xml:bas/master/MasterMapper.xml` |
| `HB76` | 1 | `be:bas/master/MasterController.java` |
| `HB77` | 2 | `be:bas/dto/MasterDeleteItem.java`<br>`be:bas/dto/MasterSaveItem.java` |
| `HB80` | 1 | `be:docs/document/dto/DocumentApprovalRequest.java` |
| `HB81` | 1 | `be:docs/document/dto/DocumentDeleteItem.java` |
| `HB82` | 1 | `be:docs/document/dto/DocumentFileRow.java` |
| `HB83` | 5 | `be:docs/documents/DocumentMapper.java`<br>`be:docs/document/dto/DocumentFileRow.java`<br>`be:docs/prp/dto/HygieneDeleteItem.java`<br>`be:docs/prp/dto/HygieneListRow.java`<br>`be:docs/prp/dto/HygieneSaveRequest.java` |
| `HB84` | 5 | `be:docs/documents/DocumentMapper.java`<br>`be:docs/prp/HygieneMapper.java`<br>`be:docs/prp/dto/HygieneDeleteItem.java`<br>`be:docs/prp/dto/HygieneListRow.java`<br>`xml:docs/documents/DocumentMapper.xml` |
| `HB85` | 2 | `be:docs/document/DocumentFileStorage.java`<br>`xml:docs/prp/HygieneMapper.xml` |
| `HB86` | 3 | `be:docs/document/DocumentService.java`<br>`be:docs/document/dto/HwpDocumentSaveRequest.java`<br>`be:docs/prp/HygieneService.java` |
| `HB87` | 2 | `be:docs/document/DocumentController.java`<br>`be:docs/prp/HygieneController.java` |
| `HB88` | 7 | `be:docs/ccp/CcpFormsMapper.java`<br>`be:docs/document/dto/DocumentTemplateResponse.java`<br>`be:docs/document/dto/DocumentTemplateRow.java`<br>`be:docs/document/dto/HwpDocumentSaveRequest.java`<br>`be:docs/prp/dto/BizOpsDeleteItem.java`<br>`be:docs/prp/dto/BizOpsSaveRequest.java`<br>`be:workflow/WorkflowMapper.java` |
| `HB89` | 8 | `be:docs/ccp/CcpFormsService.java`<br>`be:docs/template/TemplateFileNames.java`<br>`be:docs/template/TemplateFileStorage.java`<br>`be:docs/template/TemplateManifestEntry.java`<br>`be:docs/prp/BizOpsMapper.java`<br>`xml:docs/prp/BizOpsMapper.xml`<br>`xml:sys/code/approvalline/ApprovalLineMapper.xml`<br>`xml:workflow/WorkflowMapper.xml` |
| `HB90` | 6 | `be:docs/ccp/CcpFormsController.java`<br>`be:docs/document/dto/DocumentTemplateResponse.java`<br>`be:docs/template/TemplateService.java`<br>`be:docs/prp/BizOpsService.java`<br>`be:sys/code/approvalline/dto/ApprovalLineDeleteItem.java`<br>`be:workflow/dto/WorkflowDeleteItem.java` |
| `HB91` | 4 | `be:docs/template/TemplateController.java`<br>`be:docs/prp/BizOpsController.java`<br>`be:sys/code/approvalline/ApprovalLineService.java`<br>`be:workflow/WorkflowService.java` |
| `HB92` | 24 | `be:docs/template/TemplateImportService.java`<br>`be:docs/template/TemplateManifestEntry.java`<br>`be:docs/template/TemplateManifestLoader.java`<br>`be:sys/SysPayload.java`<br>`be:sys/code/approvalline/ApprovalLineController.java`<br>`be:sys/code/approvalline/ApprovalLineMapper.java`<br>`be:sys/logs/auditlog/AuditLogMapper.java`<br>`be:sys/logs/auditlog/AuditWriter.java`<br>`be:sys/code/commoncode/CommonCodeMapper.java`<br>`be:sys/code/department/DepartmentMapper.java`<br>`be:sys/logs/loginhistory/LoginHistoryMapper.java`<br>`be:sys/code/menu/MenuMgmtMapper.java`<br>`be:sys/code/role/RoleMgmtMapper.java`<br>`be:sys/logs/screenusage/ScreenUsageMapper.java`<br>`be:sys/code/user/UserMapper.java`<br>`be:workflow/WorkflowController.java`<br>`xml:sys/logs/auditlog/AuditLogMapper.xml`<br>`xml:sys/code/commoncode/CommonCodeMapper.xml`<br>`xml:sys/code/department/DepartmentMapper.xml`<br>`xml:sys/logs/loginhistory/LoginHistoryMapper.xml`<br>`xml:sys/code/menu/MenuMgmtMapper.xml`<br>`xml:sys/code/role/RoleMgmtMapper.xml`<br>`xml:sys/logs/screenusage/ScreenUsageMapper.xml`<br>`xml:sys/code/user/UserMapper.xml` |
| `HB93` | 10 | `be:docs/template/RhwpCliClient.java`<br>`be:sys/logs/auditlog/AuditLogController.java`<br>`be:sys/code/commoncode/CommonCodeController.java`<br>`be:sys/code/department/DepartmentController.java`<br>`be:sys/logs/loginhistory/LoginHistoryController.java`<br>`be:sys/code/menu/MenuMgmtController.java`<br>`be:sys/code/role/RoleMgmtController.java`<br>`be:sys/logs/screenusage/ScreenUsageController.java`<br>`be:sys/code/user/UserController.java`<br>`be:tsk/TaskMapper.java` |
| `HB94` | 13 | `be:docs/prp/EquipmentHistMapper.java`<br>`be:docs/ccp/dto/GenericMonitorSaveRequest.java`<br>`be:docs/prp/dto/HealthCertDeleteItem.java`<br>`be:sys/logs/auditlog/AuditLogService.java`<br>`be:sys/code/commoncode/CommonCodeService.java`<br>`be:sys/code/department/DepartmentService.java`<br>`be:sys/logs/loginhistory/LoginHistoryService.java`<br>`be:sys/code/menu/MenuMgmtService.java`<br>`be:sys/code/role/RoleMgmtService.java`<br>`be:sys/logs/screenusage/ScreenUsageService.java`<br>`be:sys/code/user/UserService.java`<br>`be:tsk/TaskService.java`<br>`xml:docs/prp/EquipmentHistMapper.xml` |
| `HB95` | 5 | `be:docs/prp/EquipmentHistService.java`<br>`be:docs/ccp/CcpGenericMapper.java`<br>`be:docs/prp/HealthCertMapper.java`<br>`be:tsk/TaskController.java`<br>`xml:docs/prp/HealthCertMapper.xml` |
| `HB96` | 4 | `be:docs/prp/EquipmentHistController.java`<br>`be:docs/prp/HealthCertService.java`<br>`be:tsk/DailyTaskGenerationJob.java`<br>`xml:docs/ccp/CcpGenericMapper.xml` |
| `HB97` | 6 | `be:bas/dto/EquipmentHistDeleteItem.java`<br>`be:bas/dto/EquipmentHistSaveItem.java`<br>`be:bas/dto/PestDeviceHistDeleteItem.java`<br>`be:bas/dto/PestDeviceHistSaveItem.java`<br>`be:docs/ccp/CcpGenericService.java`<br>`be:docs/prp/HealthCertController.java` |
| `HB98` | 4 | `be:docs/prp/PestDeviceHistController.java`<br>`be:docs/ccp/CcpGenericController.java`<br>`be:docs/ccp/dto/GenericMonitorDeleteItem.java`<br>`be:docs/sch/CycleScheduleGenerator.java` |
| `HB99` | 7 | `be:docs/prp/PestDeviceHistService.java`<br>`be:docs/sch/DocCycleController.java`<br>`be:docs/sch/DocCycleMapper.java`<br>`be:docs/sch/DocCycleService.java`<br>`be:docs/sch/DocumentAlarmScheduler.java`<br>`be:docs/sch/dto/DocCycleDeleteItem.java`<br>`xml:docs/sch/DocCycleMapper.xml` |
| `HB100` | 2 | `be:docs/prp/PestDeviceHistMapper.java`<br>`xml:docs/prp/PestDeviceHistMapper.xml` |
| `HB123` | 4 | `be:docs/hwp/HwpTemplateController.java`<br>`be:docs/hwp/HwpTemplateMapper.java`<br>`be:docs/hwp/HwpTemplateService.java`<br>`xml:docs/hwp/HwpTemplateMapper.xml` |
| `HB130` | 5 | `be:docs/html/htmltemplate/HtmlTemplateController.java`<br>`be:docs/html/htmltemplate/HtmlTemplateMapper.java`<br>`be:docs/html/htmltemplate/HtmlTemplateService.java`<br>`be:docs/html/htmltemplate/dto/HtmlFormVerDeleteItem.java`<br>`xml:docs/html/htmltemplate/HtmlTemplateMapper.xml` |
| `HB131` | 9 | `be:docs/html/ccpverifytemplate/CcpVerifyTemplateMapper.java`<br>`be:docs/html/hygprocess/HygProcessController.java`<br>`be:docs/html/hygprocess/HygProcessMapper.java`<br>`be:docs/html/hygprocess/HygProcessService.java`<br>`be:docs/html/hygprocess/dto/HygProcessDeleteItem.java`<br>`be:docs/html/hygprocess/dto/HygProcessListRow.java`<br>`be:docs/html/hygprocess/dto/HygProcessSaveRequest.java`<br>`xml:docs/html/ccpverifytemplate/CcpVerifyTemplateMapper.xml`<br>`xml:docs/html/hygprocess/HygProcessMapper.xml` |
| `HB132` | 2 | `be:docs/html/ccppkgtemplate/CcpPkgTemplateMapper.java`<br>`xml:docs/html/ccppkgtemplate/CcpPkgTemplateMapper.xml` |
| `HB133` | 2 | `be:docs/html/ccphtgtemplate/CcpHtgTemplateMapper.java`<br>`xml:docs/html/ccphtgtemplate/CcpHtgTemplateMapper.xml` |
| `HB134` | 2 | `be:docs/html/ccpmtltemplate/CcpMtlTemplateMapper.java`<br>`xml:docs/html/ccpmtltemplate/CcpMtlTemplateMapper.xml` |
| `HB135` | 7 | `be:draft/hyg/HygProcessDraftMapper.java`<br>`be:draft/hyg/HygProcessDraftService.java`<br>`be:draft/hyg/dto/HygProcessDraftDeleteItem.java`<br>`be:draft/hyg/dto/HygProcessDraftFormRow.java`<br>`be:draft/hyg/dto/HygProcessDraftListRow.java`<br>`be:draft/hyg/dto/HygProcessDraftSaveRequest.java`<br>`xml:draft/hyg/HygProcessDraftMapper.xml` |
| `HB136` | 1 | `be:draft/hyg/HygProcessDraftController.java` |
| `HB137` | 7 | `be:draft/ccp/CcpVerifyDraftMapper.java`<br>`be:draft/ccp/CcpVerifyDraftService.java`<br>`be:draft/ccp/dto/CcpVerifyDraftDeleteItem.java`<br>`be:draft/ccp/dto/CcpVerifyDraftFormRow.java`<br>`be:draft/ccp/dto/CcpVerifyDraftListRow.java`<br>`be:draft/ccp/dto/CcpVerifyDraftSaveRequest.java`<br>`xml:draft/ccp/CcpVerifyDraftMapper.xml` |
| `HB138` | 1 | `be:draft/ccp/CcpVerifyDraftController.java` |
| `HB139` | 9 | `be:draft/ccpmonitoring/CcpLogDraftMapper.java`<br>`be:draft/ccpmonitoring/CcpLogDraftService.java`<br>`be:draft/ccpmonitoring/dto/CcpLogDraftDeleteItem.java`<br>`be:draft/ccpmonitoring/dto/CcpLogDraftFormRow.java`<br>`be:draft/ccpmonitoring/dto/CcpLogDraftListRow.java`<br>`be:draft/ccpmonitoring/dto/CcpLogDraftPassRow.java`<br>`be:draft/ccpmonitoring/dto/CcpLogDraftRow.java`<br>`be:draft/ccpmonitoring/dto/CcpLogDraftSaveRequest.java`<br>`xml:draft/ccpmonitoring/CcpLogDraftMapper.xml` |
| `HB140` | 3 | `be:draft/ccpmonitoring/CcpMtlDraftMapper.java`<br>`be:draft/ccpmonitoring/CcpMtlDraftService.java`<br>`xml:draft/ccpmonitoring/CcpMtlDraftMapper.xml` |
| `HB141` | 1 | `be:draft/ccpmonitoring/CcpPkgDraftController.java` |
| `HB142` | 1 | `be:draft/ccpmonitoring/CcpHtgDraftController.java` |
| `HB143` | 1 | `be:draft/ccpmonitoring/CcpMtlDraftController.java` |
| `HB144` | 4 | `be:draft/hwp/HwpDraftController.java`<br>`be:draft/hwp/HwpDraftMapper.java`<br>`be:draft/hwp/HwpDraftService.java`<br>`xml:draft/hwp/HwpDraftMapper.xml` |
| `HB145` | 4 | `be:common/auth/ScreenAuthAction.java`<br>`be:common/auth/ScreenAuthInterceptor.java`<br>`be:common/auth/ScreenAuthMatch.java`<br>`be:common/auth/ScreenAuthResolver.java` |

## 충돌·확인 필요

같은 번호가 여러 파일에 붙어 있는 것은 버그가 아니라 **클러스터 라벨**이다. 다음 작업자가 재채번하지 말고, 새 모듈만 빈 번호를 쓴다.

| 태그 | 파일 수 | 비고 |
|---|---|---|
| `HF99` | 15 | sys 화면·모달·YN 공통. 고유 화면 ID가 아님 |
| `HF92` | 13 | sys API·레이아웃 클러스터 |
| `HF98` | 8 | sys Rule 클러스터 |
| `HF49` | 9 | 셸 연관 |
| `HF120` | 8 | DocForm 키트 |
| `HB92` | 24 | sys Mapper + 템플릿 매니페스트 등. 가장 큰 클러스터 |
| `HB94` | 13 | sys Service 클러스터 |
| `HB93` | 10 | sys Controller 클러스터 |
| `HB131` | 9 | 공정점검·CCP검증 HTML |
| `F41` | — | MES 잔존. 본 태그는 `useEditableRows.ts`. `resolveDelete.ts` 연관 줄에 `F41` 표기 |

`resolveDelete.ts` 헤더는 `PIPELINE[HF97]` 이고 연관에 `F41`이 남아 있다. 코드 태그는 이 패스에서 바꾸지 않는다.

## MES 잔존 `PIPELINE[Fn]` (접두 F)

MES에서 가져온 그리드·셸 모듈. **새 파일에 F 접두를 쓰지 않는다.** HF로 갈아끼우지 않는다(재채번 금지).

| 태그 | 파일 |
|---|---|
| `F33` | `fe:types/editable.ts` |
| `F34` | `fe:types/grid.ts` |
| `F35` | `fe:utils/date.ts` |
| `F41` | `fe:hooks/useEditableRows.ts` |
| `F52` | `fe:shell/pageCommands.ts` |
| `F58` | `fe:shell/validation.ts` |
| `F67` | `fe:shell/statusRules.ts` |
| `F75` | `fe:components/grid/useMesTable.ts` |
| `F78` | `fe:shell/gridRules/index.ts` |
| `F79` | `fe:shell/gridRules/types.ts` |
| `F80` | `fe:shell/gridRules/gridAccess.ts` |
| `F81` | `fe:shell/gridRules/pageGuard.ts` |
| `F82` | `fe:shell/gridRules/validateGridSave.ts` |
| `F83` | `fe:components/grid/GridChrome.tsx` |
| `F84` | `fe:components/grid/GridCrudButtons.tsx` |
| `F85` | `fe:components/grid/GridEmptyState.tsx` |
| `F86` | `fe:components/grid/GridLoadingOverlay.tsx` |
| `F87` | `fe:components/grid/GridSkeleton.tsx` |
| `F88` | `fe:components/grid/gridUtils.ts` |
| `F89` | `fe:components/grid/MesDataGrid.tsx` |
| `F90` | `fe:components/grid/GridEmptyState.tsx`<br>`fe:components/grid/GridLoadingOverlay.tsx`<br>`fe:components/grid/GridSkeleton.tsx`<br>`fe:components/grid/gridUtils.ts`<br>`fe:components/grid/MesEditableGrid.tsx` |
| `F91` | `fe:components/grid/useGridVirtual.ts` |
| `F163` | `fe:components/grid/gridPref.ts`<br>`fe:components/grid/useMesTable.ts` |
| `F164` | `fe:components/grid/gridCsv.ts` |
| `F165` | `fe:components/grid/gridFilterNormalize.ts` |
| `F166` | `fe:components/grid/GridCellDisplay.tsx` |
| `F167` | `fe:components/grid/GridErrorBoundary.tsx` |
| `F168` | `fe:components/grid/gridCellClasses.ts` |
| `F172` | `fe:shell/pageDirtyRegistry.ts` |
| `F173` | `fe:components/grid/useGridVirtual.ts` |

경로 접두: `fe:` = `frontend/haccp-web/src/`, `be:` = `backend/haccp-api/src/main/java/com/haccp/`, `xml:` = `backend/haccp-api/src/main/resources/mapper/`.
