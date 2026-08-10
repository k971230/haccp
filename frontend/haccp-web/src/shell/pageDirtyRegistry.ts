/**
 * pageDirtyRegistry — keep-alive 탭별 미저장(dirty) 검사 등록.
 *
 * 주요 역할:
 *     1. useEditableRows가 scrnCd별로 hasChanges 콜백 자동 등록
 *     2. MesShell beforeunload — F5·브라우저 탭 닫기·주소 이동 경고
 *     3. MesShell go/doClose — 앱 내 탭 전환·닫기 mesConfirm
 *
 * 설계 기준:
 *     - pageCommands와 대칭(scrnCd 키). Zustand 불필요(동기 Map)
 *     - 페이지별 수동 배선 없음 — 훅에서 자동 등록
 *     - M-D는 그리드마다 등록 → 하나라도 dirty면 탭 dirty
 *
 * PIPELINE[F172] 셸 인프라
 * PIPELINE[F41, F49, F52] 연관 — useEditableRows / MesShell / pageCommands
 */
// 역할 — React effect·context
import { useContext, useEffect, useId } from "react";
// 역할 — 탭 scrnCd 주입
import { PageScrnContext } from "@/shell/pageCommands";

/** scrnCd → (등록 id → hasChanges) — M-D는 그리드 여러 개 */
const byScrn = new Map<string, Map<string, () => boolean>>();

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) registerPageDirty — dirty 검사 등록
 *   2) useEditableRows effect에서 호출
 *   3) 성공 시 unregister 함수 반환
 */
export function registerPageDirty(
  scrnCd: string,
  id: string,
  hasChanges: () => boolean,
): () => void {
  // scrnCd가 비어 있을 때(= PageScrnContext 밖) 등록 생략
  if (!scrnCd) return () => {};
  let m = byScrn.get(scrnCd);
  // 해당 화면 맵이 없을 때(= 첫 그리드) 새 Map
  if (!m) {
    m = new Map();
    byScrn.set(scrnCd, m);
  }
  m.set(id, hasChanges);
  return () => {
    const cur = byScrn.get(scrnCd);
    // 맵이 이미 없을 때(= 다른 경로에서 정리됨) 종료
    if (!cur) return;
    cur.delete(id);
    // 등록이 모두 비었을 때(= 화면 언마운트) scrnCd 키 제거
    if (cur.size === 0) byScrn.delete(scrnCd);
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isPageDirty — 단일 화면 dirty 여부
 *   2) MesShell 탭 전환·닫기 confirm에서 호출
 *   3) 성공 시 boolean
 */
export function isPageDirty(scrnCd: string): boolean {
  // scrnCd 없을 때(= 홈·미지정) dirty 아님
  if (!scrnCd) return false;
  return isAnyPageDirty([scrnCd]);
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) isAnyPageDirty — 열린 탭 중 미저장 여부
 *   2) MesShell beforeunload에서 호출
 *   3) 성공 시 boolean
 */
export function isAnyPageDirty(scrnCds?: string[]): boolean {
  const keys = scrnCds ?? [...byScrn.keys()];
  for (const cd of keys) {
    const m = byScrn.get(cd);
    // 등록이 없을 때(= 조회 전용·미연동) 스킵
    if (!m) continue;
    for (const fn of m.values()) {
      // 한 그리드라도 dirty일 때(= 미저장) true
      if (fn()) return true;
    }
  }
  return false;
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) useRegisterPageDirty — hasChanges를 현재 scrnCd에 등록
 *   2) useEditableRows에서 호출
 *   3) 성공 시 언마운트 해제
 */
export function useRegisterPageDirty(hasChanges: () => boolean) {
  // PageHost가 주입한 현재 탭 scrnCd
  const scrnCd = useContext(PageScrnContext);
  // 동일 화면 내 그리드 구분용 안정 id
  const id = useId();

  useEffect(() => {
    // scrnCd 없을 때(= 셸 밖) 등록 안 함
    if (!scrnCd) return;
    return registerPageDirty(scrnCd, id, hasChanges);
  }, [scrnCd, id, hasChanges]);
}
