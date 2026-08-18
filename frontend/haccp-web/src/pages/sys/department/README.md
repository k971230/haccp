# 부서 관리 (`department-management`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../README.md) 4장.

## 파일

| 파일 | 책임 |
|---|---|
| `DepartmentManagementPage.tsx` | 렌더·상태·API 호출·룩업 모달 호출. 좌 부서 트리 + 우 CRUD 그리드 |
| `DepartmentManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `TREE_ALL` · 컬럼 팩터리(상위부서 셀 버튼 포함) · `DEPT_RULES` · `newDeptRow` · `matchDept` · `sortByDeptCd` · `buildDeptTree` |

## 화면 규칙

- 부서코드(`deptCd`)는 신규 행에서만 입력 가능 (`DEPT_RULES.newOnly`)
- 상위부서는 직접 타이핑하지 않고 **코드 룩업 모달**로 고른다. `allowEmpty`라서 `(없음)`을 고르면 최상위 부서가 된다
- 룩업 후보는 자기 자신과 자기 하위를 제외한 목록이다(순환 방지)
- 좌측 노드를 고르면 해당 부서와 하위가 그리드에 남고, 행추가 시 상위부서가 선택 노드로 채워진다

## API · SP · 테이블

| 동작 | API (`api/sys/departmentApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listDepartments` | `sp_department_management_r_000` | `tbl_dept` (상위부서명 self JOIN) |
| 저장 | `saveDepartments` | `sp_department_management_c_000` | `tbl_dept` |
| 삭제 검증 | `validateDeleteDepartments` | `sp_department_management_delete_blocker_r_000` | `tbl_dept` `tbl_user` |
| 삭제 | `deleteDepartments` | `sp_department_management_d_000` | `tbl_dept` `tbl_user` |

삭제는 하위 부서 또는 소속 사용자가 있으면 차단된다.

## 모달

```ts
openModal("CodeLookup", { title, options, value, allowEmpty: true, onSelect });
```

구현은 `components/common/modal/CodeLookupModal.tsx`. 이 화면은 팝업 JSX를 갖지 않는다.

## pref 키

`scrnCd = department-management` · `persistId = dept-mgmt-master-v2` — 값 변경 금지.
