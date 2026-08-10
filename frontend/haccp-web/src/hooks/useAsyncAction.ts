/**
 * useAsyncAction — 비동기 처리 중복 실행을 막고 진행 상태를 알려준다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 같은 key로 진행 중인 처리가 있으면 두 번째 호출을 무시한다 — 버튼 연속 클릭으로 같은 기록이 두 번 저장되는 것을 막는다
 *   2) key별 진행 여부를 따로 알 수 있어 조회 중에도 저장 버튼만 스피너로 바꿀 수 있다
 *   3) onError를 넘기면 예외를 삼키고 호출부가 계속 진행하며, 넘기지 않으면 그대로 다시 던진다
 *
 * PIPELINE[HF39] 커스텀 훅
 */
// 역할 — 진행 중 key 집합 관리
import { useCallback, useRef, useState } from "react";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 중복 실행 차단 래퍼(run)와 진행 상태(busy/isBusy)를 만들어 준다
 *   2) 조회·저장·삭제 버튼이 있는 화면에서 컴포넌트 최상단에 한 번 호출한다
 *   3) run은 처리 결과를 반환하고, 중복 호출로 무시된 경우 undefined를 반환한다
 */
export function useAsyncAction() {
  // 즉시 판정용 잠금 집합 — 상태 반영을 기다리면 빠른 연속 클릭을 놓친다
  const locks = useRef(new Set<string>());
  // 화면 렌더용 진행 중 key 집합
  const [busyKeys, setBusyKeys] = useState<Set<string>>(() => new Set());

  /** key를 주면 그 처리만, 생략하면 무엇이든 진행 중인지 판정한다 */
  const isBusy = useCallback(
    (key?: string) => {
      if (!key) return busyKeys.size > 0;
      return busyKeys.has(key);
    },
    [busyKeys],
  );

  /** 하나라도 진행 중이면 true — 화면 전체 Dim 처리에 쓴다 */
  const busy = busyKeys.size > 0;

  /**
   * 개발자: 박승우
   * 일자: 2026-08-05
   * 코멘트:
   *   1) 비동기 처리를 key 단위로 직렬 실행한다
   *   2) 버튼 클릭 핸들러에서 API 호출을 감싸 호출한다
   *   3) 같은 key가 진행 중이면 아무 것도 하지 않고 undefined를 반환한다
   */
  const run = useCallback(
    async <T,>(
      // 실행할 비동기 처리 — 보통 API 호출과 후속 재조회를 담는다
      fn: () => Promise<T>,
      // 처리 구분 key — "search", "save", "del" 처럼 버튼별로 나눈다. 생략하면 전체 공용 잠금
      key = "_",
      // 오류 처리 — 넘기면 예외를 삼키고 undefined를 반환한다. 생략하면 호출부로 다시 던진다
      onError?: (e: unknown) => void,
    ): Promise<T | undefined> => {
      // 이미 같은 key가 진행 중일 때(= 중복 클릭) 즉시 종료
      if (locks.current.has(key)) return undefined;
      locks.current.add(key);
      setBusyKeys((prev) => new Set(prev).add(key));
      try {
        return await fn();
      } catch (e) {
        if (onError) {
          onError(e);
          return undefined;
        }
        throw e;
      } finally {
        // 성공·실패·예외 어느 경로로 끝나도 잠금을 반드시 푼다
        locks.current.delete(key);
        setBusyKeys((prev) => {
          const next = new Set(prev);
          next.delete(key);
          return next;
        });
      }
    },
    [],
  );

  return { busy, isBusy, run };
}
