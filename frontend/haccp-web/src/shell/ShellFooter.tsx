/**
 * ShellFooter — 화면 하단 상태 바 (회사·부서·사용자·저작권).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 지금 어느 회사·누구로 로그인했는지 항상 보이게 한다
 *   2) 여러 업체를 대행 관리하는 컨설턴트가 회사를 착각한 채 기록을 남기는 사고를 막는 장치다
 *   3) mes-web처럼 배경 이미지를 쓰지 않고 단색 바로 그린다 — 추가 정적 파일 없이 같은 정보를 준다
 *
 * PIPELINE[HF64] 하단 상태 바
 * PIPELINE[HF49] 연관 — 셸
 */
// 역할 — 로그인 사용자 타입
import type { LoginUser } from "@/types/common";

interface ShellFooterProps {
  user: LoginUser | null;
}

/** "이름(코드)" 형태로 합친다 — 둘 다 없으면 null이라 해당 칸이 아예 렌더되지 않는다 */
function fmtPair(name?: string | null, code?: string | null) {
  if (!name && !code) return null;
  return `${name ?? "-"}(${code ?? "-"})`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 하단 바에 회사·부서·사용자와 저작권을 표시한다
 *   2) 셸 최하단에 한 번 마운트한다
 *   3) user가 null이면 제품명과 저작권만 남는다 — 값이 없어도 레이아웃이 흔들리지 않는다
 */
export function ShellFooter({
  // 로그인 사용자 — 인증 스토어 구독값. 로그아웃 직후 짧게 null이 될 수 있다
  user,
}: ShellFooterProps) {
  const co = fmtPair(user?.coNm, user?.coCd);
  const dept = fmtPair(user?.deptNm, user?.deptCd);
  // 사용자는 이름(아이디) 조합 — 동명이인 구분을 위해 아이디를 함께 보여준다
  const who = user?.userNm || user?.userId ? `${user?.userNm ?? "-"}(${user?.userId ?? "-"})` : null;

  return (
    <footer className="relative z-10 flex h-6 shrink-0 items-center justify-between gap-2 bg-[#1a3676] px-2 text-[10px] leading-none text-white sm:px-3">
      <div className="flex min-w-0 flex-1 items-center gap-1 overflow-hidden text-white/90">
        <span className="shrink-0 font-semibold text-white">HACCP 일지관리</span>
        {co && (
          <>
            <span className="shrink-0 text-white/40">|</span>
            <span className="truncate">{co}</span>
          </>
        )}
        {dept && (
          <>
            <span className="shrink-0 text-white/40">|</span>
            <span className="truncate">{dept}</span>
          </>
        )}
        {who && (
          <>
            <span className="shrink-0 text-white/40">|</span>
            <span className="truncate font-medium text-white">{who}</span>
          </>
        )}
      </div>
      <span className="shrink-0 text-right text-[9px] text-white/85">
        © 2026 RMA Co., Ltd. All rights reserved.
      </span>
    </footer>
  );
}
