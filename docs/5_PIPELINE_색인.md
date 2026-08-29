# 5. PIPELINE 색인 — 태그에서 파일로

> 개발자: 박승우 · 일자: 2026-08-29
> 소스의 `PIPELINE[HFn]` / `PIPELINE[HBn]` 주석에서 뽑았다.

코드에 태그를 달아 두고 여기서 파일을 찾는다.
「HF130 이 뭐였지」를 검색 없이 알 수 있게 하려는 표다.

**손으로 고치지 않는다.** 태그를 더하거나 파일을 옮긴 뒤 다시 뽑는다.

```sh
node scripts/gen_pipeline_index.mjs           # 다시 만든다
node scripts/gen_pipeline_index.mjs --check   # 어긋나면 실패한다 (CI)
```

**태그 하나를 여러 파일이 달 수 있다.** 같은 층에 있는 형제들이다 —
표는 그 전부를 싣는다. 태그 칸이 빈 줄은 바로 위 태그에 딸린 파일이다.

업무가 어떤 순서로 흐르는지는 태그가 아니라 파이프라인 문서를 본다 —
[`backend/haccp-api/PIPELINE.md`](../backend/haccp-api/PIPELINE.md) ·
[`frontend/haccp-web/PIPELINE.md`](../frontend/haccp-web/PIPELINE.md).

## 프론트 (HF) — 태그 85개 · 파일 268곳

| 태그 | 파일 | 무엇 |
|---|---|---|
| `HF1` | `frontend/haccp-web/src/main.tsx` | React 진입점 |
| `HF2` | `frontend/haccp-web/src/main.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/routes/AppRoutes.tsx` | 라우팅 분기 |
| `HF3` | `frontend/haccp-web/src/api/documentApi.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/api/http.ts` | HTTP 클라이언트 |
|  | `frontend/haccp-web/src/api/taskWorkflowApi.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/config/envConfig.ts` | 연관 — http 타임아웃 3계층 |
| `HF4` | `frontend/haccp-web/src/api/authApi.ts` | API 레이어 |
|  | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
| `HF16` | `frontend/haccp-web/src/api/menuApi.ts` | API 레이어 |
| `HF17` | `frontend/haccp-web/src/api/codeApi.ts` | API 레이어 |
|  | `frontend/haccp-web/src/hooks/useCommonCodes.ts` | 연관 모듈 |
| `HF18` | `frontend/haccp-web/src/api/prefApi.ts` | API 레이어 |
| `HF19` | `frontend/haccp-web/src/api/viewLogApi.ts` | API 레이어 |
|  | `frontend/haccp-web/src/shell/useViewLog.ts` | 연관 — 조회 로그 API·셸 |
| `HF29` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/sys/code/approvalline/ApprovalLineManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authKeys.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/loginPrefs.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/stores/authStore.ts` | Zustand 스토어 |
| `HF30` | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/stores/modalStore.ts` | Zustand 스토어 |
|  | `frontend/haccp-web/src/stores/tabStore.ts` | Zustand 스토어 |
| `HF31` | `frontend/haccp-web/src/config/envConfig.ts` | 전역 설정 |
| `HF32` | `frontend/haccp-web/src/types/common.ts` | 공통 모듈 |
| `HF35` | `frontend/haccp-web/src/lib/datetime.ts` | 공통 모듈 |
| `HF36` | `frontend/haccp-web/src/lib/cn.ts` | 공통 모듈 |
| `HF37` | `frontend/haccp-web/src/lib/buttonVariants.ts` | 공통 모듈 |
| `HF38` | `frontend/haccp-web/src/lib/icons.tsx` | 공통 모듈 |
| `HF39` | `frontend/haccp-web/src/hooks/useAsyncAction.ts` | 커스텀 훅 |
|  | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/sys/code/approvalline/ApprovalLineManagementPage.tsx` | 연관 모듈 |
| `HF41` | `frontend/haccp-web/src/components/layout/SearchArea.tsx` | 연관 — useEditableRows / pageCommands(search) |
| `HF49` | `frontend/haccp-web/src/shell/dialog.tsx` | 연관 — 셸 |
|  | `frontend/haccp-web/src/shell/errors.ts` | 연관 — 셸 |
|  | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 앱 셸 |
|  | `frontend/haccp-web/src/shell/HomeView.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/messages.ts` | 연관 — 셸 |
|  | `frontend/haccp-web/src/shell/screenRegistry.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/ShellFooter.tsx` | 연관 — 셸 |
|  | `frontend/haccp-web/src/shell/ShellTabBar.tsx` | 앱 셸 |
|  | `frontend/haccp-web/src/shell/TabContextMenu.tsx` | 앱 셸 |
|  | `frontend/haccp-web/src/shell/tabRoute.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/useActiveGrid.ts` | 연관 — HaccpShell / pageCommands |
|  | `frontend/haccp-web/src/shell/useSection.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/useViewLog.ts` | 연관 — 조회 로그 API·셸 |
|  | `frontend/haccp-web/src/stores/tabStore.ts` | 연관 모듈 |
| `HF51` | `frontend/haccp-web/src/pages/tsk/TodayTasksPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/screenRegistry.tsx` | 화면 레지스트리 |
| `HF52` | `frontend/haccp-web/src/components/layout/SearchArea.tsx` | 연관 — useEditableRows / pageCommands(search) |
|  | `frontend/haccp-web/src/pages/flow/ca/corrective/CorrectiveActionManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/sys/code/approvalline/ApprovalLineManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/useActiveGrid.ts` | 연관 — HaccpShell / pageCommands |
|  | `frontend/haccp-web/src/shell/useSection.ts` | 연관 모듈 |
| `HF54` | `frontend/haccp-web/src/shell/errors.ts` | 셸 인프라 |
| `HF55` | `frontend/haccp-web/src/shell/messages.ts` | 셸 인프라 |
| `HF56` | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/dialog.tsx` | 셸 인프라 |
| `HF62` | `frontend/haccp-web/src/shell/HomeView.tsx` | 홈 화면 |
| `HF64` | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/manualUrl.ts` | 하단 상태 바 |
|  | `frontend/haccp-web/src/shell/ShellFooter.tsx` | 하단 상태 바 |
| `HF66` | `frontend/haccp-web/src/shell/HaccpShell.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/SideMenu.tsx` | 셸 인프라 |
| `HF68` | `frontend/haccp-web/src/shell/tabRoute.ts` | 셸 인프라 |
| `HF70` | `frontend/haccp-web/src/shell/useViewLog.ts` | 셸 인프라 |
| `HF74` | `frontend/haccp-web/src/main.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authCrossTab.ts` | 셸 인프라 |
|  | `frontend/haccp-web/src/shell/authPaths.ts` | 연관 — authCrossTab |
|  | `frontend/haccp-web/src/shell/authSession.ts` | 연관 — 멀티탭 로그아웃 신호 |
|  | `frontend/haccp-web/src/shell/mesSec.ts` | 패널 활성 — useActiveGrid 시각과 동일 emerald |
|  | `frontend/haccp-web/src/shell/useActiveGrid.ts` | 셸 인프라 — mes-web useActiveGrid와 동일 계약 |
| `HF76` | `frontend/haccp-web/src/shell/useSection.ts` | 셸 인프라 |
| `HF81` | `frontend/haccp-web/src/components/form/DocFormLayout.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/form/DocFormSearchToolbar.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/hooks/useDocFormSession.ts` | 연관 모듈 |
| `HF82` | `frontend/haccp-web/src/api/documentApi.ts` | API 레이어 |
|  | `frontend/haccp-web/src/components/document/ApprovalDocumentPreview.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/document/DocumentApprovalToolbar.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/document/documentPreviewRegistry.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/hooks/useDocIdxQuery.ts` | 문서 deep-link |
|  | `frontend/haccp-web/src/lib/camelKeys.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/lib/documentNav.ts` | 문서 네비게이션 |
|  | `frontend/haccp-web/src/pages/docs/hwp/HwpTemplateManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/appr/attach/ApprovalAttachPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxPage.tsx` | 연관 모듈 |
| `HF83` | `frontend/haccp-web/src/components/form/DocFormSearchToolbar.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/hooks/useDocFormSession.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/appr/attach/ApprovalAttachPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxPage.tsx` | DOC 화면 |
|  | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxRule.ts` | 문서함 그리드 규칙 |
| `HF84` | `frontend/haccp-web/src/lib/rhwpStudio.ts` | HWP 문서 편집 연관 |
|  | `frontend/haccp-web/src/pages/docs/hwp/HwpTemplateManagementPage.tsx` | 연관 모듈 |
| `HF85` | `frontend/haccp-web/src/components/form/DocFormSearchToolbar.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/hooks/useDocFormSession.ts` | 연관 모듈 |
| `HF86` | `frontend/haccp-web/src/api/sys/approvalLineApi.ts` | 결재선 관리 API |
|  | `frontend/haccp-web/src/pages/sys/code/approvalline/ApprovalLineManagementPage.tsx` | 연관 모듈 |
| `HF87` | `frontend/haccp-web/src/api/taskWorkflowApi.ts` | 워크플로 화면 API |
|  | `frontend/haccp-web/src/lib/camelKeys.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/ca/corrective/CorrectiveActionManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/sys/code/approvalline/ApprovalLineManagementPage.tsx` | 결재선 관리 화면 |
|  | `frontend/haccp-web/src/pages/sys/code/approvalline/ApprovalLineManagementRule.ts` | 결재선 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/tsk/TodayTasksPage.tsx` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskMapper.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskService.java` | 연관 모듈 |
| `HF88` | `frontend/haccp-web/src/api/taskWorkflowApi.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/lib/docStatus.ts` | 오늘 할 일 화면 |
|  | `frontend/haccp-web/src/pages/tsk/TodayTasksPage.tsx` | 오늘 할 일 화면 |
|  | `frontend/haccp-web/src/pages/tsk/TodayTasksRule.ts` | 오늘 할 일 화면 |
|  | `frontend/haccp-web/src/shell/HomeView.tsx` | 연관 모듈 |
| `HF89` | `frontend/haccp-web/src/api/docs/docCycleApi.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/api/taskWorkflowApi.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/docs/sch/ScheduleCycleManagementPage.tsx` | 문서주기관리 화면 |
|  | `frontend/haccp-web/src/pages/docs/sch/ScheduleCycleManagementRule.ts` | 문서주기관리 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/flow/ca/corrective/CorrectiveActionManagementPage.tsx` | 개선조치 관리 화면 |
|  | `frontend/haccp-web/src/pages/flow/ca/corrective/CorrectiveActionManagementRule.ts` | 개선조치 그리드 규칙 |
| `HF90` | `frontend/haccp-web/src/hooks/useGridAccess.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/ca/corrective/CorrectiveActionManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/sys/code/approvalline/ApprovalLineManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/resolveDelete.ts` | 연관 모듈 |
| `HF92` | `frontend/haccp-web/src/api/sys/auditLogApi.ts` | 변경 감사 로그 API |
|  | `frontend/haccp-web/src/api/sys/commonCodeApi.ts` | 공통코드 API |
|  | `frontend/haccp-web/src/api/sys/departmentApi.ts` | 부서 관리 API |
|  | `frontend/haccp-web/src/api/sys/loginHistoryApi.ts` | 로그인 이력 API |
|  | `frontend/haccp-web/src/api/sys/menuApi.ts` | 메뉴 관리 API |
|  | `frontend/haccp-web/src/api/sys/roleApi.ts` | 권한그룹 관리 API |
|  | `frontend/haccp-web/src/api/sys/screenUsageApi.ts` | 화면 이용 통계 API |
|  | `frontend/haccp-web/src/api/sys/sysTypes.ts` | 시스템 관리 API 타입 |
|  | `frontend/haccp-web/src/api/sys/userApi.ts` | 사용자 관리·서명 API |
|  | `frontend/haccp-web/src/components/layout/PageCard.tsx` | UI 컴포넌트 — mes-web PageCard와 동일 계약 |
|  | `frontend/haccp-web/src/components/layout/ResizableSplit.tsx` | 레이아웃 분할 |
|  | `frontend/haccp-web/src/components/layout/TreePanelSearch.tsx` | 트리 검색 |
|  | `frontend/haccp-web/src/lib/treeFilter.ts` | 트리 필터 |
|  | `frontend/haccp-web/src/pages/sys/code/user/UserManagementPage.tsx` | 연관 모듈 |
| `HF93` | `frontend/haccp-web/src/components/layout/pageClasses.ts` | UI 컴포넌트 — mes-web pageClasses와 동일 계약 |
| `HF95` | `frontend/haccp-web/src/components/layout/SearchArea.tsx` | UI 컴포넌트 — mes-web SearchArea와 동일 계약 |
| `HF96` | `frontend/haccp-web/src/hooks/useGridAccess.ts` | 그리드 접근 훅 |
|  | `frontend/haccp-web/src/pages/sys/code/user/UserManagementPage.tsx` | 연관 모듈 |
| `HF97` | `frontend/haccp-web/src/pages/sys/code/user/UserManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/resolveDelete.ts` | 삭제 대상 해석 |
| `HF98` | `frontend/haccp-web/src/pages/sys/code/commoncode/CommonCodeRule.ts` | 공통코드 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/sys/code/department/DepartmentManagementRule.ts` | 부서 관리 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/sys/code/menu/MenuManagementRule.ts` | 메뉴 관리 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/sys/code/role/RoleManagementRule.ts` | 권한그룹 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/sys/code/user/UserManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/sys/code/user/UserManagementRule.ts` | 사용자 관리 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/sys/logs/auditlog/AuditLogRule.ts` | 감사 로그 규칙 |
|  | `frontend/haccp-web/src/pages/sys/logs/loginhistory/LoginHistoryRule.ts` | 로그인 이력 규칙 |
|  | `frontend/haccp-web/src/pages/sys/logs/screenusage/ScreenUsageStatisticsRule.ts` | 화면 이용 통계 규칙 |
| `HF99` | `frontend/haccp-web/src/components/common/modal/CodeLookupModal.tsx` | 코드 조회 팝업 |
|  | `frontend/haccp-web/src/components/common/modal/GlobalModal.tsx` | 전역 모달 호스트 |
|  | `frontend/haccp-web/src/components/common/modal/modalTypes.ts` | 공통 모달 타입 |
|  | `frontend/haccp-web/src/components/common/modal/UserSignModal.tsx` | 사용자 서명 팝업 |
|  | `frontend/haccp-web/src/components/layout/LogPageShell.tsx` | 로그 화면 공통 셸 |
|  | `frontend/haccp-web/src/lib/yn.ts` | YN 공통 |
|  | `frontend/haccp-web/src/pages/sys/code/commoncode/CommonCodePage.tsx` | 공통코드 관리 |
|  | `frontend/haccp-web/src/pages/sys/code/department/DepartmentManagementPage.tsx` | 부서 관리 |
|  | `frontend/haccp-web/src/pages/sys/code/menu/MenuManagementPage.tsx` | 메뉴 관리 |
|  | `frontend/haccp-web/src/pages/sys/code/role/RoleManagementPage.tsx` | 권한그룹 관리 |
|  | `frontend/haccp-web/src/pages/sys/code/user/UserManagementPage.tsx` | 사용자 관리 그리드 화면 |
|  | `frontend/haccp-web/src/pages/sys/logs/auditlog/AuditLogPage.tsx` | 변경 감사 로그 |
|  | `frontend/haccp-web/src/pages/sys/logs/loginhistory/LoginHistoryPage.tsx` | 로그인 이력 |
|  | `frontend/haccp-web/src/pages/sys/logs/screenusage/ScreenUsageStatisticsPage.tsx` | 화면 이용 통계 |
|  | `frontend/haccp-web/src/stores/modalStore.ts` | 연관 모듈 |
| `HF102` | `frontend/haccp-web/src/components/document/DocumentApprovalToolbar.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/ui/SysYnBadge.tsx` | 공통코드 훅 |
|  | `frontend/haccp-web/src/hooks/useCommonCodes.ts` | 공통코드 훅 |
| `HF103` | `frontend/haccp-web/src/components/document/ApprovalDocumentPreview.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/document/DocumentApprovalToolbar.tsx` | 문서 결재 툴바 |
| `HF112` | `frontend/haccp-web/src/components/ui/Input.tsx` | UI 컴포넌트 |
| `HF113` | `frontend/haccp-web/src/components/ui/MesButton.tsx` | UI 컴포넌트 |
| `HF114` | `frontend/haccp-web/src/main.tsx` | 연관 모듈 |
| `HF115` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 로그인 화면 |
| `HF119` | `frontend/haccp-web/src/components/form/DocFormLayout.tsx` | DB형 문서 레이아웃 |
| `HF120` | `frontend/haccp-web/src/components/form/DocCell.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/form/DocDeviationFooter.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/form/DocFormLayout.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/form/DocFormSearchToolbar.tsx` | 문서 공통 헤더 |
|  | `frontend/haccp-web/src/hooks/useDocFormSession.ts` | DB형 문서 세션 |
|  | `frontend/haccp-web/src/pages/docs/hwp/HwpTemplateManagementPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/flow/box/documentbox/DocumentBoxPage.tsx` | 연관 모듈 |
| `HF121` | `frontend/haccp-web/src/lib/camelKeys.ts` | API 키 정규화 |
| `HF122` | `frontend/haccp-web/src/components/form/DocCell.tsx` | 문서 셀 입력 |
|  | `frontend/haccp-web/src/lib/docDateTime.ts` | DocForm 날짜시각 |
| `HF123` | `frontend/haccp-web/src/api/docs/docCycleApi.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/api/docs/hwpTemplateApi.ts` | 사용양식관리 API |
|  | `frontend/haccp-web/src/components/ui/SysYnBadge.tsx` | 사용양식 구분 |
|  | `frontend/haccp-web/src/pages/docs/hwp/HwpTemplateFileHistModal.tsx` | 사용양식 파일 이력 팝업 |
|  | `frontend/haccp-web/src/pages/docs/hwp/HwpTemplateManagementPage.tsx` | 사용양식관리 |
|  | `frontend/haccp-web/src/pages/docs/hwp/HwpTemplateManagementRule.ts` | 사용양식관리 그리드 규칙 |
|  | `frontend/haccp-web/src/pages/docs/sch/ScheduleCycleManagementPage.tsx` | 연관 모듈 |
| `HF124` | `frontend/haccp-web/src/api/docs/docCycleApi.ts` | 문서주기관리 API |
|  | `frontend/haccp-web/src/components/form/DocDeviationFooter.tsx` | 문서 이탈 푸터 |
|  | `frontend/haccp-web/src/pages/docs/sch/ScheduleCycleManagementPage.tsx` | 연관 모듈 |
| `HF130` | `frontend/haccp-web/src/api/docs/htmlFormApi.ts` | HTML양식 API |
|  | `frontend/haccp-web/src/pages/docs/html-form/HtmlFormTemplatePage.tsx` | HTML양식 원본 공통 화면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/htmlFormTemplateShared.ts` | HTML양식 원본 공통 규칙 |
|  | `frontend/haccp-web/src/pages/docs/html-form/htmltemplate/HtmlTemplatePage.tsx` | HTML양식 원본 화면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/htmltemplate/HtmlTemplateRule.ts` | HTML양식 원본 규칙 |
|  | `frontend/haccp-web/src/pages/docs/html-form/htmltemplate/HygPrcPaper.tsx` | 공정점검 지면 |
| `HF131` | `frontend/haccp-web/src/pages/docs/html-form/ccpverifytemplate/CcpChkPaper.tsx` | CCP 검증점검 지면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccpverifytemplate/CcpVerifyTemplatePage.tsx` | CCP 검증점검 양식 화면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccpverifytemplate/CcpVerifyTemplateRule.ts` | CCP 검증점검 양식 규칙 |
| `HF132` | `frontend/haccp-web/src/pages/docs/html-form/ccppkgtemplate/CcpPkgPaper.tsx` | CCP-1B 포장일지 지면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccppkgtemplate/CcpPkgTemplatePage.tsx` | CCP-1B 포장일지 양식 화면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccppkgtemplate/CcpPkgTemplateRule.ts` | CCP-1B 포장일지 양식 규칙 |
| `HF133` | `frontend/haccp-web/src/pages/docs/html-form/ccphtgtemplate/CcpHtgPaper.tsx` | CCP-2B 가열일지 지면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccphtgtemplate/CcpHtgTemplatePage.tsx` | CCP-2B 가열일지 양식 화면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccphtgtemplate/CcpHtgTemplateRule.ts` | CCP-2B 가열일지 양식 규칙 |
| `HF134` | `frontend/haccp-web/src/pages/docs/html-form/ccpmtltemplate/CcpMtlPaper.tsx` | CCP-3P 금속검출일지 지면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccpmtltemplate/CcpMtlTemplatePage.tsx` | CCP-3P 금속검출일지 양식 화면 |
|  | `frontend/haccp-web/src/pages/docs/html-form/ccpmtltemplate/CcpMtlTemplateRule.ts` | CCP-3P 금속검출일지 양식 규칙 |
| `HF135` | `frontend/haccp-web/src/components/form/htmlFormPaperShared.tsx` | HTML 양식 지면 공통 |
| `HF160` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authCrossTab.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authKeys.ts` | 셸 인프라 |
|  | `frontend/haccp-web/src/shell/loginPrefs.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/stores/authStore.ts` | 연관 모듈 |
| `HF161` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authCrossTab.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authKeys.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authPaths.ts` | 셸 인프라 — G-22 Path basename 정합 |
|  | `frontend/haccp-web/src/shell/authSession.ts` | 셸 인프라 |
|  | `frontend/haccp-web/src/stores/authStore.ts` | 연관 모듈 |
| `HF162` | `frontend/haccp-web/src/pages/auth/LoginPage.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/authKeys.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/shell/loginPrefs.ts` | 셸 인프라 |
|  | `frontend/haccp-web/src/stores/authStore.ts` | 연관 모듈 |
| `HF169` | `frontend/haccp-web/src/components/ui/HaccpLogo.tsx` | UI 컴포넌트 |
| `HF172` | `frontend/haccp-web/src/api/draft/htmlFormDraftTypes.ts` | 양식 작성 API 계약 |
|  | `frontend/haccp-web/src/api/draft/hygProcessDraftApi.ts` | 위생공정 작성 API |
|  | `frontend/haccp-web/src/components/document/documentPreviewRegistry.ts` | 연관 모듈 |
|  | `frontend/haccp-web/src/components/document/HtmlDocumentPreview.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/draft/html/HygProcessDraftRule.ts` | 위생공정 작성 규칙 |
|  | `frontend/haccp-web/src/pages/draft/htmlFormDraftShared.test.ts` | 양식 작성 공통 규칙 |
|  | `frontend/haccp-web/src/pages/draft/htmlFormDraftShared.ts` | 양식 작성 공통 규칙 |
| `HF173` | `frontend/haccp-web/src/components/document/HtmlDocumentPreview.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/draft/html/HygProcessDraftPage.tsx` | 위생공정 작성 화면 |
|  | `frontend/haccp-web/src/pages/draft/HtmlFormDraftPage.tsx` | 양식 작성 공통 화면 |
| `HF174` | `frontend/haccp-web/src/pages/draft/HtmlFormLookupModal.tsx` | 양식 선택 팝업 |
| `HF175` | `frontend/haccp-web/src/api/draft/ccpVerifyDraftApi.ts` | CCP 검증점검 작성 API |
|  | `frontend/haccp-web/src/pages/draft/html/CcpVerifyDraftRule.ts` | CCP 검증점검 작성 규칙 |
| `HF176` | `frontend/haccp-web/src/pages/draft/html/CcpVerifyDraftPage.tsx` | CCP 검증점검 작성 화면 |
| `HF177` | `frontend/haccp-web/src/api/draft/ccpMonitoringDraftApi.ts` | CCP 모니터링 작성 API |
|  | `frontend/haccp-web/src/pages/draft/htmlFormLogRows.test.ts` | CCP 모니터링 작성 기록행 |
| `HF178` | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpPkgDraftPage.tsx` | CCP 포장 작성 화면 |
|  | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpPkgDraftRule.ts` | CCP 포장 작성 규칙 |
| `HF179` | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpHtgDraftPage.tsx` | CCP 가열 작성 화면 |
|  | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpHtgDraftRule.ts` | CCP 가열 작성 규칙 |
| `HF180` | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpMtlDraftPage.tsx` | CCP 금속검출 작성 화면 |
|  | `frontend/haccp-web/src/pages/draft/ccp-monitoring/CcpMtlDraftRule.ts` | CCP 금속검출 작성 규칙 |
| `HF181` | `frontend/haccp-web/src/pages/draft/HtmlFormDeviationSignal.tsx` | 이탈·개선조치 시그널 |
| `HF182` | `frontend/haccp-web/src/api/draft/hwpDraftApi.ts` | HWP 작성 API |
|  | `frontend/haccp-web/src/components/document/HwpDocumentPreview.tsx` | 연관 모듈 |
|  | `frontend/haccp-web/src/pages/draft/hwp-doc/HwpDraftPage.tsx` | HWP 작성 화면 |
|  | `frontend/haccp-web/src/pages/draft/hwp-doc/HwpDraftRule.ts` | HWP 작성 규칙 |
|  | `frontend/haccp-web/src/pages/draft/hwp-doc/HwpEditorPane.tsx` | HWP 작성 편집기 패널 |
| `HF183` | `frontend/haccp-web/src/pages/draft/HwpTaskLookupModal.tsx` | HWP 오늘 할일 팝업 |
| `HF184` | `frontend/haccp-web/src/components/document/ApprovalDocumentPreview.tsx` | 결재 문서 미리보기 |
|  | `frontend/haccp-web/src/components/document/documentPreviewRegistry.ts` | 결재 문서 미리보기 |
|  | `frontend/haccp-web/src/components/document/HtmlDocumentPreview.tsx` | 결재 문서 미리보기 |
|  | `frontend/haccp-web/src/components/document/HwpDocumentPreview.tsx` | 결재 문서 미리보기 |
| `HF185` | `frontend/haccp-web/src/pages/flow/appr/attach/ApprovalAttachPage.tsx` | 결재 첨부 화면 |
|  | `frontend/haccp-web/src/pages/flow/appr/attach/ApprovalAttachRule.ts` | 결재 첨부 화면 |
| `HF200` | `frontend/haccp-web/src/shell/gridRules/gridSave.ts` | 편집 그리드 저장 공통 |

## 백엔드 (HB) — 태그 79개 · 파일 273곳

| 태그 | 파일 | 무엇 |
|---|---|---|
| `HB1` | `backend/haccp-api/src/main/java/com/haccp/HaccpApiApplication.java` | Spring Boot 진입 |
| `HB2` | `backend/haccp-api/src/main/java/com/haccp/HaccpApiApplication.java` | 연관 — application.yml |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/DailyTaskGenerationJob.java` | 연관 모듈 |
| `HB3` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | Spring 설정 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtProvider.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/WebConfig.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateController.java` | 연관 모듈 |
| `HB4` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/auth/AuthService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtProvider.java` | Spring 설정 |
| `HB5` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/WebConfig.java` | Spring 설정 |
| `HB6` | `backend/haccp-api/src/main/java/com/haccp/common/exception/BizException.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/exception/GlobalExceptionHandler.java` | 전역 예외 처리 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/exception/NotFoundException.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/exception/SqlUserMessage.java` | 연관 모듈 |
| `HB7` | `backend/haccp-api/src/main/java/com/haccp/common/exception/GlobalExceptionHandler.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/exception/SqlUserMessage.java` | 예외 처리 |
| `HB8` | `backend/haccp-api/src/main/java/com/haccp/common/exception/BizException.java` | 예외 처리 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/exception/NotFoundException.java` | 예외 처리 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/validation/DeleteValidation.java` | 연관 모듈 |
| `HB9` | `backend/haccp-api/src/main/java/com/haccp/common/response/CommonResponse.java` | common 모듈 |
| `HB10` | `backend/haccp-api/src/main/java/com/haccp/common/response/ErrorResponse.java` | common 모듈 |
| `HB11` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/context/LoginUser.java` | common 모듈 |
| `HB12` | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtFilter.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/context/LoginUserContext.java` | common 모듈 |
| `HB13` | `backend/haccp-api/src/main/java/com/haccp/common/config/SecurityHeadersFilter.java` | 공통 설정 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/context/RequestMeta.java` | common 모듈 |
| `HB19` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthController.java` | REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/auth/AuthService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtProvider.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/WebConfig.java` | 연관 모듈 |
| `HB20` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/auth/AuthService.java` | Service |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/JwtProvider.java` | 연관 모듈 |
| `HB23` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/LoginRequest.java` | auth DTO |
| `HB24` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/UserLoginRow.java` | auth DTO |
| `HB25` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/ScreenAuthRow.java` | auth DTO |
| `HB26` | `backend/haccp-api/src/main/java/com/haccp/auth/dto/LoginResponse.java` | auth DTO |
| `HB27` | `backend/haccp-api/src/main/java/com/haccp/auth/AuthMapper.java` | MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/auth/AuthService.java` | 연관 모듈 |
| `HB28` | `backend/haccp-api/src/main/resources/mapper/auth/AuthMapper.xml` | MyBatis XML |
| `HB30` | `backend/haccp-api/src/main/java/com/haccp/menu/dto/MenuRow.java` | menu DTO |
| `HB31` | `backend/haccp-api/src/main/java/com/haccp/menu/MenuController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/menu/MenuMapper.java` | MyBatis 매퍼 |
| `HB32` | `backend/haccp-api/src/main/java/com/haccp/menu/MenuController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/menu/MenuMapper.xml` | MyBatis XML |
| `HB33` | `backend/haccp-api/src/main/java/com/haccp/menu/MenuController.java` | REST Controller |
| `HB34` | `backend/haccp-api/src/main/java/com/haccp/code/dto/CodeRow.java` | code DTO |
| `HB35` | `backend/haccp-api/src/main/java/com/haccp/code/CodeController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/code/CodeMapper.java` | MyBatis 매퍼 |
| `HB36` | `backend/haccp-api/src/main/java/com/haccp/code/CodeController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/code/CodeMapper.xml` | MyBatis XML |
| `HB37` | `backend/haccp-api/src/main/java/com/haccp/code/CodeController.java` | REST Controller |
| `HB38` | `backend/haccp-api/src/main/java/com/haccp/pref/dto/GridPrefRow.java` | pref DTO |
| `HB39` | `backend/haccp-api/src/main/java/com/haccp/pref/dto/GridPrefSaveRequest.java` | pref DTO |
| `HB40` | `backend/haccp-api/src/main/java/com/haccp/pref/PrefController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/pref/PrefMapper.java` | MyBatis 매퍼 |
| `HB41` | `backend/haccp-api/src/main/java/com/haccp/pref/PrefController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/pref/PrefMapper.xml` | MyBatis XML |
| `HB42` | `backend/haccp-api/src/main/java/com/haccp/pref/PrefController.java` | REST Controller |
| `HB43` | `backend/haccp-api/src/main/java/com/haccp/log/dto/ViewLogItem.java` | log DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatDailyJob.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatService.java` | 연관 모듈 |
| `HB44` | `backend/haccp-api/src/main/java/com/haccp/log/LogMapper.java` | MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewLogController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatDailyJob.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatService.java` | 연관 모듈 |
| `HB45` | `backend/haccp-api/src/main/java/com/haccp/log/ViewLogController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatDailyJob.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/log/LogMapper.xml` | MyBatis XML |
| `HB46` | `backend/haccp-api/src/main/java/com/haccp/log/ViewLogController.java` | REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatDailyJob.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatService.java` | 연관 모듈 |
| `HB47` | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatDailyJob.java` | 화면 이용 통계 집계 |
|  | `backend/haccp-api/src/main/java/com/haccp/log/ViewStatService.java` | 화면 이용 통계 집계 |
| `HB50` | `backend/haccp-api/src/main/java/com/haccp/common/validation/DeleteBlocker.java` | common 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/validation/DeleteValidation.java` | 연관 모듈 |
| `HB51` | `backend/haccp-api/src/main/java/com/haccp/common/validation/DeleteBlocker.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/validation/DeleteValidation.java` | common 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentDeleteItem.java` | 연관 모듈 |
| `HB62` | `backend/haccp-api/src/main/java/com/haccp/flow/ca/dto/DocCorrectiveDto.java` | ccp DTO |
| `HB63` | `backend/haccp-api/src/main/java/com/haccp/flow/ca/DocCorrectiveMapper.java` | Mapper |
| `HB64` | `backend/haccp-api/src/main/java/com/haccp/flow/ca/DocCorrectiveSupport.java` | 문서 푸터 지원 |
| `HB72` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentApprovalRequest.java` | 연관 모듈 |
| `HB80` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentApprovalRequest.java` | doc DTO |
| `HB81` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentDeleteItem.java` | doc DTO |
| `HB82` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentFileStorage.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentFileRow.java` | doc DTO |
| `HB83` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentMapper.java` | MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentFileRow.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateRow.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateService.java` | 연관 모듈 |
| `HB84` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentMapper.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/docs/documents/DocumentMapper.xml` | MyBatis XML |
| `HB85` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentFileStorage.java` | doc 파일 저장 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/RhwpCliClient.java` | 연관 모듈 |
| `HB86` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentFileStorage.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentService.java` | Service |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/HwpDocumentSaveRequest.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/RhwpCliClient.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskMapper.java` | 연관 모듈 |
| `HB87` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/DocumentController.java` | REST Controller |
| `HB88` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateResponse.java` | 템플릿 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateRow.java` | 템플릿 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/HwpDocumentSaveRequest.java` | doc DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateMapper.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateFileStorage.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/docs/hwp/HwpTemplateMapper.xml` | 연관 모듈 |
| `HB89` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateRow.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateFileNames.java` | 템플릿 파일명 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateFileStorage.java` | 템플릿 파일 저장 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateImportService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateManifestEntry.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateManifestLoader.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/sys/code/approvalline/ApprovalLineMapper.xml` | 결재선 관리 MyBatis XML |
| `HB90` | `backend/haccp-api/src/main/java/com/haccp/docs/documents/dto/DocumentTemplateResponse.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateFileNames.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateFileStorage.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateImportService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateManifestLoader.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateService.java` | 템플릿 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/approvalline/dto/ApprovalLineDeleteItem.java` | 결재선 삭제 DTO |
| `HB91` | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateController.java` | 템플릿 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/approvalline/ApprovalLineService.java` | 결재선 관리 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskMapper.java` | 연관 모듈 |
| `HB92` | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateMapper.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateFileNames.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateImportService.java` | 템플릿 배포 초기화 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateManifestEntry.java` | 템플릿 매니페스트 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/templates/TemplateManifestLoader.java` | 템플릿 매니페스트 로더 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/approvalline/ApprovalLineController.java` | 결재선 관리 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/approvalline/ApprovalLineMapper.java` | 결재선 관리 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/commoncode/CommonCodeMapper.java` | 공통코드 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/department/DepartmentMapper.java` | 부서 관리 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/menu/MenuMgmtMapper.java` | 메뉴 관리 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/role/RoleMgmtMapper.java` | 권한그룹 관리 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/user/UserMapper.java` | 사용자 관리 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/auditlog/AuditLogMapper.java` | 감사 이력 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/auditlog/AuditWriter.java` | 변경 감사 적재 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/loginhistory/LoginHistoryMapper.java` | 로그인 이력 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/screenusage/ScreenUsageMapper.java` | 화면 이용 통계 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/SysPayload.java` | 시스템 관리 공용 유틸 |
|  | `backend/haccp-api/src/main/resources/mapper/docs/hwp/HwpTemplateMapper.xml` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/sys/code/commoncode/CommonCodeMapper.xml` | 공통코드 MyBatis XML |
|  | `backend/haccp-api/src/main/resources/mapper/sys/code/department/DepartmentMapper.xml` | 부서 관리 MyBatis XML |
|  | `backend/haccp-api/src/main/resources/mapper/sys/code/menu/MenuMgmtMapper.xml` | 메뉴 관리 MyBatis XML |
|  | `backend/haccp-api/src/main/resources/mapper/sys/code/role/RoleMgmtMapper.xml` | 권한그룹 관리 MyBatis XML |
|  | `backend/haccp-api/src/main/resources/mapper/sys/code/user/UserMapper.xml` | 사용자 관리 MyBatis XML |
|  | `backend/haccp-api/src/main/resources/mapper/sys/logs/auditlog/AuditLogMapper.xml` | 감사 이력 MyBatis XML |
|  | `backend/haccp-api/src/main/resources/mapper/sys/logs/loginhistory/LoginHistoryMapper.xml` | 로그인 이력 MyBatis XML |
|  | `backend/haccp-api/src/main/resources/mapper/sys/logs/screenusage/ScreenUsageMapper.xml` | 화면 이용 통계 MyBatis XML |
| `HB93` | `backend/haccp-api/src/main/java/com/haccp/docs/templates/RhwpCliClient.java` | rhwp CLI PDF 변환 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/commoncode/CommonCodeController.java` | 공통코드 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/department/DepartmentController.java` | 부서 관리 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/menu/MenuMgmtController.java` | 메뉴 관리 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/role/RoleMgmtController.java` | 권한그룹 관리 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/user/UserController.java` | 사용자 관리 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/user/UserSignController.java` | 사용자 서명 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/auditlog/AuditLogController.java` | 감사 이력 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/loginhistory/LoginHistoryController.java` | 로그인 이력 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/screenusage/ScreenUsageController.java` | 화면 이용 통계 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskMapper.java` | 워크플로 작업 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/tsk/TaskMapper.xml` | 워크플로 작업 매퍼 |
| `HB94` | `backend/haccp-api/src/main/java/com/haccp/docs/sch/CycleScheduleGenerator.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleMapper.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocumentAlarmScheduler.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/dto/DocCycleDeleteItem.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/flow/ca/CorrectiveActionController.java` | 개선조치관리 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/flow/ca/CorrectiveActionMapper.java` | 개선조치관리 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/flow/ca/CorrectiveActionService.java` | 개선조치관리 업무 서비스 |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/commoncode/CommonCodeService.java` | 공통코드 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/department/DepartmentService.java` | 부서 관리 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/menu/MenuMgmtService.java` | 메뉴 관리 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/role/RoleMgmtService.java` | 권한그룹 관리 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/code/user/UserService.java` | 사용자 관리 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/auditlog/AuditLogService.java` | 감사 이력 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/loginhistory/LoginHistoryService.java` | 로그인 이력 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/sys/logs/screenusage/ScreenUsageService.java` | 화면 이용 통계 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/DailyTaskGenerationJob.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskService.java` | 워크플로 작업 서비스 |
|  | `backend/haccp-api/src/main/resources/mapper/docs/sch/DocCycleMapper.xml` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/flow/ca/CorrectiveActionMapper.xml` | 개선조치관리 MyBatis XML |
| `HB95` | `frontend/haccp-web/src/pages/tsk/TodayTasksPage.tsx` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskController.java` | 워크플로 작업 Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/tsk/TaskService.java` | 연관 모듈 |
| `HB96` | `backend/haccp-api/src/main/java/com/haccp/tsk/DailyTaskGenerationJob.java` | 워크플로 일정 생성 |
| `HB98` | `backend/haccp-api/src/main/java/com/haccp/docs/sch/CycleScheduleGenerator.java` | 문서주기 예정일 생성기 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleController.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleMapper.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleService.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocumentAlarmScheduler.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/dto/DocCycleDeleteItem.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/resources/mapper/docs/sch/DocCycleMapper.xml` | 연관 모듈 |
| `HB99` | `backend/haccp-api/src/main/java/com/haccp/docs/sch/CycleScheduleGenerator.java` | 연관 모듈 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleController.java` | 문서주기 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleMapper.java` | 문서주기 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocCycleService.java` | 문서주기 업무 서비스 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/DocumentAlarmScheduler.java` | 문서 마감 알림 스케줄러 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/sch/dto/DocCycleDeleteItem.java` | 문서주기 삭제 DTO |
|  | `backend/haccp-api/src/main/resources/mapper/docs/sch/DocCycleMapper.xml` | 문서주기 MyBatis XML |
| `HB123` | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateController.java` | 사용양식 REST Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateMapper.java` | 사용양식 MyBatis 매퍼 |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/hwp/HwpTemplateService.java` | 사용양식 업무 서비스 |
|  | `backend/haccp-api/src/main/resources/mapper/docs/hwp/HwpTemplateMapper.xml` | 사용양식 MyBatis XML |
| `HB130` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/htmltemplate/dto/HtmlFormVerDeleteItem.java` | HTML양식 원본 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/htmltemplate/HtmlTemplateController.java` | HTML양식 원본 Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/htmltemplate/HtmlTemplateMapper.java` | HTML양식 원본 Mapper |
|  | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/htmltemplate/HtmlTemplateService.java` | HTML양식 원본 Service |
|  | `backend/haccp-api/src/main/resources/mapper/docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | HTML양식 원본 XML |
| `HB131` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.java` | CCP 검증점검 양식 Mapper |
|  | `backend/haccp-api/src/main/resources/mapper/docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | CCP 검증점검 양식 XML |
| `HB132` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.java` | CCP-1B 포장일지 양식 Mapper |
|  | `backend/haccp-api/src/main/resources/mapper/docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml` | CCP-1B 포장일지 양식 XML |
| `HB133` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.java` | CCP-2B 가열일지 양식 Mapper |
|  | `backend/haccp-api/src/main/resources/mapper/docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml` | CCP-2B 가열일지 양식 XML |
| `HB134` | `backend/haccp-api/src/main/java/com/haccp/docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.java` | CCP-3P 금속검출일지 양식 Mapper |
|  | `backend/haccp-api/src/main/resources/mapper/docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml` | CCP-3P 금속검출일지 양식 XML |
| `HB135` | `backend/haccp-api/src/main/java/com/haccp/draft/DraftSupport.java` | 양식 작성 공용 유틸 |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftDeleteItem.java` | 양식 작성 공용 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftFormRow.java` | 양식 작성 공용 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftListRow.java` | 양식 작성 공용 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftSaveRequest.java` | 양식 작성 공용 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/html/HygProcessDraftMapper.java` | 위생공정 작성 Mapper |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/html/HygProcessDraftService.java` | 위생공정 작성 Service |
|  | `backend/haccp-api/src/main/resources/mapper/draft/html/HygProcessDraftMapper.xml` | 위생공정 작성 XML |
| `HB136` | `backend/haccp-api/src/main/java/com/haccp/draft/html/HygProcessDraftController.java` | 위생공정 작성 Controller |
| `HB137` | `backend/haccp-api/src/main/java/com/haccp/draft/html/CcpVerifyDraftMapper.java` | CCP 검증점검 작성 Mapper |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/html/CcpVerifyDraftService.java` | CCP 검증점검 작성 Service |
|  | `backend/haccp-api/src/main/resources/mapper/draft/html/CcpVerifyDraftMapper.xml` | CCP 검증점검 작성 XML |
| `HB138` | `backend/haccp-api/src/main/java/com/haccp/draft/html/CcpVerifyDraftController.java` | CCP 검증점검 작성 Controller |
| `HB139` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpLogDraftMapper.java` | CCP 모니터링 작성 Mapper |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpLogDraftService.java` | CCP 모니터링 작성 Service |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftLogRow.java` | CCP 모니터링 작성 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftPassRow.java` | CCP 모니터링 작성 DTO |
|  | `backend/haccp-api/src/main/resources/mapper/draft/ccpmonitoring/CcpLogDraftMapper.xml` | CCP 모니터링 작성 XML |
| `HB140` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpLogDraftControllerBase.java` | CCP 모니터링 작성 공통 Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpMtlDraftMapper.java` | CCP 금속검출 작성 Mapper |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpMtlDraftService.java` | CCP 금속검출 작성 Service |
|  | `backend/haccp-api/src/main/resources/mapper/draft/ccpmonitoring/CcpMtlDraftMapper.xml` | CCP 금속검출 작성 XML |
| `HB143` | `backend/haccp-api/src/main/java/com/haccp/draft/ccpmonitoring/CcpMtlDraftController.java` | CCP 금속검출 작성 Controller |
| `HB144` | `backend/haccp-api/src/main/java/com/haccp/draft/dto/DraftTaskRow.java` | HWP 작성 DTO |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/hwpdoc/HwpDraftController.java` | HWP 작성 Controller |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/hwpdoc/HwpDraftMapper.java` | HWP 작성 Mapper |
|  | `backend/haccp-api/src/main/java/com/haccp/draft/hwpdoc/HwpDraftService.java` | HWP 작성 Service |
|  | `backend/haccp-api/src/main/resources/mapper/draft/hwpdoc/HwpDraftMapper.xml` | HWP 작성 XML |
| `HB145` | `backend/haccp-api/src/main/java/com/haccp/common/auth/ScreenAuthAction.java` | 화면 권한 인터셉터 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/auth/ScreenAuthInterceptor.java` | 화면 권한 인터셉터 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/auth/ScreenAuthMatch.java` | 화면 권한 인터셉터 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/auth/ScreenAuthResolver.java` | 화면 권한 인터셉터 |
|  | `backend/haccp-api/src/main/java/com/haccp/common/config/WebConfig.java` | 연관 모듈 |
