/**
 * useActiveGrid — 다중 그리드 화면의 활성 그리드 추적 (WinForms activeGrid).
 *
 * 주요 역할:
 *     1. 셸 단축키 행추가/저장/삭제 타겟 결정 (마지막 클릭·포커스 그리드)
 *     2. 초기·조회 성공·마스터 행 선택 시 default(마스터)로 복귀
 *     3. bind()로 패널 클릭/포커스 시 active 갱신 + mes-sec-active
 *        (헤더·ring = CSV excel 틴트 그린 — global.css)
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음 — Page가 add/save/del을 active 기준으로 분기
 *     - 패널 GridCrudButtons는 고정 타겟(이 훅과 무관)
 *     - 활성 시각: .mes-sec-active → emerald-50/200/700 (MesButton variant=excel)
 *
 * PIPELINE[HF74] 셸 인프라 — mes-web useActiveGrid와 동일 계약
 * PIPELINE[HF49, HF52] 연관 — HaccpShell / pageCommands
 */
// 역할 — useCallback·useState
import { useCallback, useState } from "react";

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) useActiveGrid — 활성 그리드 id 상태
 *   2) CommonCode·N그리드 Page / useSection에서 호출
 *   3) 성공 시 active·bind·resetToDefault 반환
 */
export function useActiveGrid<T extends string>(
  // 최초 활성 그리드 id — 보통 마스터
  initial: T,
  // 리셋 기준 id — 미지정 시 initial (조회·마스터 선택 후 복귀)
  defaultId?: T,
) {
  // 현재 활성 그리드 id — 셸 CRUD 타겟
  const [active, setActive] = useState<T>(initial);
  // 기본 그리드 id — resetToDefault 목표
  const def = defaultId ?? initial;

  // 특정 id가 활성인지 — sec.is("d") 대응
  const is = useCallback((id: T) => active === id, [active]);

  /**
   * 개발자: 박승우
   * 일자: 2026-07-10
   * 코멘트:
   *   1) resetToDefault — 마스터(default)로 활성 복귀
   *   2) 조회 성공·마스터 행 선택 직후 Page에서 호출
   *   3) 성공 시 active=def (디테일에 남아 저장되는 버그 방지)
   */
  const resetToDefault = useCallback(() => setActive(def), [def]);

  /**
   * 개발자: 박승우
   * 일자: 2026-07-10
   * 코멘트:
   *   1) bind — 패널 래퍼 props (클릭/포커스 → setActive)
   *   2) Page 마스터/디테일 패널 div에 전개
   *   3) 성공 시 mes-sec-active — 헤더·ring이 CSV(excel) 틴트 그린
   */
  const bind = useCallback(
    // 이 패널의 그리드 id — "h"|"d" 또는 "parent"|"user"
    (id: T, extra?: string) => ({
      // extra + 활성 시 mes-sec-active
      className: [extra, `mes-sec${active === id ? " mes-sec-active" : ""}`].filter(Boolean).join(" "),
      // 캡처 단계 클릭 시 활성 그리드 설정
      onClickCapture: () => setActive(id),
      // 캡처 단계 포커스 시 활성 그리드 설정
      onFocusCapture: () => setActive(id),
      // data 속성으로 그리드 id 노출 (디버그·테스트)
      "data-active-grid": id,
    }),
    [active],
  );

  return { active, setActive, is, bind, defaultId: def, resetToDefault };
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) useSection — M-D 2그리드(h/d) 전용 별칭
 *   2) So/Po/Receipt 등 M-D Page에서 셸 CRUD 라우팅
 *   3) reset() = 마스터 h 복귀 (조회·마스터 선택 시)
 */
export function useSection(
  // 최초 섹션 — 기본 마스터 "h"
  initial: "h" | "d" = "h",
) {
  // h/d 전용 useActiveGrid — default도 initial(보통 h)
  const ag = useActiveGrid<"h" | "d">(initial, initial);
  return {
    // 현재 활성 섹션 — "h"|"d"
    sec: ag.active,
    // 판정 — sec.is("d")
    is: ag.is,
    // 패널 bind
    bind: ag.bind,
    // 직접 설정 — onSetActive={() => sec.setSec("d")}
    setSec: ag.setActive,
    // 마스터 복귀 — loadHeaders 성공·onActivateHeader 선두
    reset: ag.resetToDefault,
  };
}
