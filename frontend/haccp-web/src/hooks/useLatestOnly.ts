/**
 * useLatestOnly — 늦게 온 응답이 최신 선택을 덮지 않게 한다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) 적재를 시작할 때 번호를 하나 뽑고, 응답이 왔을 때 그 번호가 아직 최신인지 묻는다
 *   2) 좌측에서 행을 고르면 우측 상세를 읽는 화면이 쓴다
 *   3) 상태를 쓰기 **직전**에 물어야 한다 — await 뒤마다 묻는다
 *
 * 왜 잠금이 아니라 번호인가: `useAsyncAction` 의 key 잠금은 **두 번째 호출을 버린다**
 * (중복 제출을 막으려는 장치라 거기서는 그게 맞다).
 * 선택이 바뀌는 적재에 그걸 쓰면 **새 선택의 적재가 조용히 사라져서**
 * 좌측은 B 인데 우측은 A 가 남는다. 그 상태로 저장하면 사람이 본 것과 다른 것이 저장된다.
 * 여기서 필요한 것은 「나중 것이 이긴다」이지 「먼저 것이 이긴다」가 아니다.
 *
 * `AbortController` 를 안 쓰는 이유: 요청을 끊는 것이 목적이 아니라
 * **낡은 응답이 상태를 덮지 않는 것**이 목적이다.
 *
 * 같은 일을 손으로 하는 자리가 하나 더 있다 — `HtmlFormDraftPage.tsx` 의 `detailSeq`.
 * 그쪽은 E2E 가 지키고 있어 이번에는 안 건드렸다. 고칠 일이 생기면 이 훅으로 모은다.
 */
// 역할 — 화면 수명 동안 번호를 이어 간다
import { useRef } from "react";

/**
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) 번호를 세는 알맹이. React 를 안 쓴다
 *   2) 훅이 화면당 하나 만들어 들고 있는다
 *   3) 시험은 이 함수를 직접 부른다 — 훅은 이걸 ref 에 담는 한 겹일 뿐이다
 */
export function makeLatestOnly(): () => () => boolean {
  let seq = 0;
  return () => {
    seq += 1;
    const mine = seq;
    return () => seq === mine;
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) 부르면 이번 적재의 「아직 최신인가」 판정 함수를 돌려준다
 *   2) await 하기 전에 부르고, 상태를 쓰기 전에 그 함수를 확인한다
 *   3) 참조가 안 바뀌므로 useCallback 의존에 그대로 넣어도 된다
 *
 * ```ts
 * const begin = useLatestOnly();
 * const load = useCallback(async (id: string) => {
 *   const isLatest = begin();
 *   const data = await api.detail(id);
 *   if (!isLatest()) return;   // 그 사이 다른 행을 골랐다
 *   setDetail(data);
 * }, [begin]);
 * ```
 */
export function useLatestOnly(): () => () => boolean {
  const ref = useRef<(() => () => boolean) | null>(null);
  if (!ref.current) ref.current = makeLatestOnly();
  return ref.current;
}
