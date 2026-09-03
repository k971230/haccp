/**
 * ShellFooter — 화면 하단 상태 바 (회사·부서·사용자·저작권).
 *
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 지금 어느 회사·누구로 로그인했는지 항상 보이게 한다
 *   2) 여러 업체를 대행 관리하는 컨설턴트가 회사를 착각한 채 기록을 남기는 사고를 막는 장치다
 *   3) 도움말은 활성 화면 정적 HTML 을 새 탭으로 연다. API 를 타지 않는다
 *
 * PIPELINE[HF64] 하단 상태 바
 * PIPELINE[HF49] 연관 — 셸
 */
// 역할 — 도움말 아이콘
import { CircleHelp, KeyRound } from "lucide-react";
// 역할 — 로그인 사용자 타입
import type { LoginUser } from "@/types/common";
// 역할 — 활성 화면 → 정적 매뉴얼 주소. 없으면 버튼을 숨긴다
import { manualUrlOf } from "@/shell/manualUrl";
// 역할 — 비밀번호 변경 팝업
import { useModalStore } from "@/stores/modalStore";

interface ShellFooterProps {
  user: LoginUser | null;
  // 지금 활성 탭 화면코드 — 매뉴얼 파일명과 같다
  scrnCd?: string | null;
}

/** "이름(코드)" 형태로 합친다 — 둘 다 없으면 null이라 해당 칸이 아예 렌더되지 않는다 */
function fmtPair(name?: string | null, code?: string | null) {
  if (!name && !code) return null;
  return `${name ?? "-"}(${code ?? "-"})`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 하단 바에 회사·부서·사용자와 저작권을 표시한다
 *   2) 셸 최하단에 한 번 마운트한다
 *   3) 매뉴얼 주소가 있을 때만 물음표를 그린다. 없으면 저작권만 남는다
 */
export function ShellFooter({
  // 로그인 사용자 — 인증 스토어 구독값. 로그아웃 직후 짧게 null이 될 수 있다
  user,
  // 활성 화면코드 — 화이트리스트에 있을 때만 도움말을 연다
  scrnCd,
}: ShellFooterProps) {
  // 정적 매뉴얼 URL — SCREEN_PATH 밖이거나 비면 null
  const manualUrl = manualUrlOf(scrnCd);
  const openModal = useModalStore((s) => s.openModal);
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
      <div className="flex shrink-0 items-center gap-1.5">
        {user && (
          <button
            type="button"
            // 본인 비밀번호 변경 — 로그인 중이면 항상
            title="비밀번호 변경"
            aria-label="비밀번호 변경"
            onClick={() => openModal("PasswordChange", {})}
            className="inline-flex h-[18px] w-[18px] items-center justify-center rounded-full bg-yellow-300 text-black ring-1 ring-white hover:bg-yellow-200"
          >
            <KeyRound className="h-3.5 w-3.5" strokeWidth={2.75} />
          </button>
        )}
        {manualUrl && (
          <button
            type="button"
            // 활성 화면 매뉴얼 — 백엔드 없이 새 탭으로 연다
            title="도움말"
            aria-label="도움말"
            onClick={() => {
              window.open(manualUrl, "_blank", "noopener,noreferrer");
            }}
            // 남색 바 대비 — 밝은 노랑 원·검정 획·흰 테두리
            className="inline-flex h-[18px] w-[18px] items-center justify-center rounded-full bg-yellow-300 text-black ring-1 ring-white hover:bg-yellow-200"
          >
            <CircleHelp className="h-3.5 w-3.5" strokeWidth={2.75} />
          </button>
        )}
        <span className="shrink-0 text-right text-[9px] text-white/85">
          © 2026 RMA Co., Ltd. All rights reserved.
        </span>
      </div>
    </footer>
  );
}
