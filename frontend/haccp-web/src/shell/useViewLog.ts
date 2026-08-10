/**
 * useViewLog — 어떤 화면을 얼마나 봤는지 모아 서버로 보낸다 (UV/PV).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 활성 화면이 바뀔 때 직전 화면의 진입·이탈 시각을 기록하고, 주기적으로 묶어서 한 번에 전송한다
 *   2) 담당자가 실제로 쓰는 기록 화면을 알면 메뉴 배치·교육 순서를 근거 있게 정할 수 있다
 *   3) 화면 하나 이동마다 호출하면 요청이 과해져 배치로 모은다. 창을 떠날 때는 남은 것을 즉시 보낸다
 *
 * PIPELINE[HF70] 셸 인프라
 * PIPELINE[HF19, HF49] 연관 — 조회 로그 API·셸
 */
// 역할 — 활성 화면 변화 감지·버퍼 유지
import { useEffect, useRef } from "react";
// 역할 — 조회 로그 배치 전송 API
import { collectViewLogs, type ViewLogItem } from "@/api/viewLogApi";
// 역할 — 전송 주기 설정 (OPS_GLOBAL_CONFIG)
import { VIEW_LOG_FLUSH_MS } from "@/config/envConfig";
// 역할 — 서버가 받는 일시 문자열 생성
import { formatLocalDateTime } from "@/lib/datetime";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 활성 화면코드를 받아 화면별 체류 이벤트를 모으고 주기적으로 전송한다
 *   2) 셸에서 활성 탭 화면코드를 넘겨 한 번 호출한다
 *   3) 전송 실패는 무시한다 — 통계 유실을 감수하고 업무 흐름을 우선한다
 */
export function useViewLog(
  // 현재 보고 있는 화면코드 — 홈이거나 탭이 없으면 null. 값이 바뀌는 순간이 화면 이동 시점이다
  activeCd: string | null
) {
  // 아직 보내지 않은 이벤트 — 상태로 두면 쌓을 때마다 리렌더되어 화면이 느려진다
  const buffer = useRef<ViewLogItem[]>([]);
  // 현재 머무는 화면과 그 진입 시각
  const current = useRef<{ scrnCd: string; enterDt: string } | null>(null);
  // 직전에 보던 화면 — 이동 경로(어디서 왔는지) 분석용
  const prevScrnCd = useRef<string | null>(null);

  // 모아둔 이벤트를 서버로 보낸다. 실패해도 되돌리지 않는다(같은 이벤트 재전송으로 통계가 부풀지 않게)
  const flush = useRef(() => {
    if (buffer.current.length === 0) return;
    const items = buffer.current;
    buffer.current = [];
    void collectViewLogs(items);
  });

  // 활성 화면이 바뀌면 직전 화면의 체류 구간을 확정해 버퍼에 넣는다
  useEffect(() => {
    const now = formatLocalDateTime();

    // 머물던 화면이 있고 화면이 실제로 바뀌었을 때만 구간을 닫는다
    if (current.current && current.current.scrnCd !== activeCd) {
      buffer.current.push({
        scrnCd: current.current.scrnCd,
        enterDt: current.current.enterDt,
        leaveDt: now,
        // 직전 화면 — 첫 진입이면 undefined라 전송 본문에서 빠진다
        refScrnCd: prevScrnCd.current ?? undefined,
      });
      prevScrnCd.current = current.current.scrnCd;
      current.current = null;
    }

    // 새 화면 진입 — 홈(null)은 기록하지 않는다. 업무 화면 이용만 집계 대상이다
    if (activeCd && (!current.current || current.current.scrnCd !== activeCd)) {
      current.current = { scrnCd: activeCd, enterDt: now };
    }
  }, [activeCd]);

  // 주기 전송 + 창을 떠날 때 남은 이벤트 처리
  useEffect(() => {
    const timer = window.setInterval(() => flush.current(), VIEW_LOG_FLUSH_MS);

    // 탭을 닫거나 브라우저를 종료할 때 — 머물던 화면 구간까지 닫아 보낸다
    const onLeave = () => {
      if (current.current) {
        buffer.current.push({
          scrnCd: current.current.scrnCd,
          enterDt: current.current.enterDt,
          leaveDt: formatLocalDateTime(),
          refScrnCd: prevScrnCd.current ?? undefined,
        });
        current.current = null;
      }
      flush.current();
    };

    // visibilitychange는 모바일·백그라운드 전환에서 pagehide보다 먼저 확실히 온다
    const onVisibility = () => {
      if (document.visibilityState === "hidden") onLeave();
    };

    window.addEventListener("pagehide", onLeave);
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener("pagehide", onLeave);
      document.removeEventListener("visibilitychange", onVisibility);
      // 셸 언마운트(로그아웃) 시점에도 남은 이벤트를 보낸다
      onLeave();
    };
  }, []);
}
