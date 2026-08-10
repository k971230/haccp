/**
 * pageCommands — MES 셸 인프라 모듈.
 *
 * 주요 역할:
 *     1. MesShell(F49) / Page(F115~F156) 지원 유틸
 *     2. 탭·다이얼로그·메시지·검증·단축키 등 횡단 관심사
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음.
 *     - *Page.tsx가 shell을 import(단방향).
 *
 * 일자: 2026-07-10
 * 개발자: 박승우
 * 구현내용: 전수 주석(레벨3).
 *
 * PIPELINE[F52] 셸 인프라
 * PIPELINE[F49, F52] 연관 모듈
 */
// React: Context·effect·ref 훅
import { createContext, useContext, useEffect, useRef } from "react";
// Zustand: scrnCd별 명령 레지스트리 스토어
import { create } from "zustand";

/**
 * frmMETIS 상단 공통 툴바 ↔ 활성 화면 디스패치.
 *
 * WinForms 원본: 상단 toolStrip 의 btnSearch/btnNew/btnSave/btnDelete/btnPrint/btnExcel/btnTransfer 클릭 시
 *   `(ActiveMdiChild as BaseForm01).Search()/AddRecord()/SaveRecord()/DeleteRecord()/PrintRecord()/
 *    Export_GridToExcel()/Transfer_Information()` 을 호출(폼별 override).
 * 웹 대응: 각 화면(탭)이 `usePageCommands(scrnCd, {...})` 로 자신의 처리 함수를 전역 레지스트리에 등록하고,
 *   셸 상단 툴바는 "현재 활성 탭(scrnCd)"의 명령만 꺼내 호출. 미등록 명령은 버튼 비활성.
 *
 * BaseForm01 메서드 ↔ 명령 키:
 *   Search()→search(조회, Ctrl+Q) · AddRecord()→add(행추가, Ctrl+Shift+A)
 *   SaveRecord()→save(저장, Ctrl+S) · DeleteRecord()→del(삭제, Ctrl+Shift+D)
 *   PrintRecord()→print(인쇄, Ctrl+P) · Transfer_Information()→transfer(전송, Ctrl+Shift+E)
 *   탭 닫기 → Ctrl+Shift+F4 (셸 builtin, Ctrl+F4=브라우저 탭 닫기 회피)
 *   엑셀은 그리드 GridChrome CSV 버튼(화면별) — pageCommands 미사용
 */
export interface PageCommands {
  /** 조회 (Search, Ctrl+Q) */
  search?: () => void;
  /** 그리드 행추가 (AddRecord, Ctrl+Shift+A) — Ctrl+A는 전체선택과 충돌 */
  add?: () => void;
  /** 저장 (SaveRecord, Ctrl+S) */
  save?: () => void;
  /** 삭제 (DeleteRecord, Ctrl+Shift+D) — Ctrl+D는 북마크와 충돌 */
  del?: () => void;
  /** 인쇄 (PrintRecord, Ctrl+P) — 미등록 시 셸 printActiveTab */
  print?: () => void;
  /** 전송/일괄 (Transfer_Information, Ctrl+Shift+E) — Ctrl+T는 브라우저 새 탭과 충돌 */
  transfer?: () => void;
}

/** CommandKey — PageCommands 키 유니온. */
export type CommandKey = keyof PageCommands;

/** CommandState — scrnCd별 등록 맵·register/unregister. */
interface CommandState {
  /** scrnCd → 등록된 명령. 탭은 keep-alive 라 여러 화면이 동시 등록됨 → 활성 탭으로 선택. */
  byScrn: Record<string, PageCommands>;
  // 화면 명령 등록
  register: (scrnCd: string, cmds: PageCommands) => void;
  // 화면 명령 해제
  unregister: (scrnCd: string) => void;
}

/** pageCommands 전역 스토어 — scrnCd별 등록된 명령 맵 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) useCommandStore — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const useCommandStore = create<CommandState>((set) => ({
  // scrnCd별 명령 맵 초기값
  byScrn: {},
  // 화면 명령 등록 — 기존 맵에 scrnCd 키로 병합
  register: (scrnCd, cmds) => set((s) => ({ byScrn: { ...s.byScrn, [scrnCd]: cmds } })),
  // 화면 명령 해제 — scrnCd 키 삭제 후 맵 갱신
  unregister: (scrnCd) =>
    set((s) => {
      // 기존 맵 얕은 복사
      const next = { ...s.byScrn };
      // 해당 scrnCd 항목 제거
      delete next[scrnCd];
      // 갱신된 맵으로 스토어 반영
      return { byScrn: next };
    }),
}));

/** 탭 콘텐츠에 현재 화면의 scrnCd 를 주입 (셸의 PageHost 가 제공). */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) PageScrnContext — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const PageScrnContext = createContext<string>("");

/**
 * 화면(페이지)에서 호출 — 자신의 공통 명령을 셸 상단 툴바에 등록.
 * 핸들러 최신값은 ref 로 유지해 리렌더마다 재등록하지 않음(가용 버튼 집합은 키 존재로 결정).
 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) usePageCommands — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function usePageCommands(cmds: PageCommands) {
  // PageHost가 주입한 현재 탭 scrnCd
  const scrnCd = useContext(PageScrnContext);
  // 스토어 register 액션
  const register = useCommandStore((s) => s.register);
  // 스토어 unregister 액션
  const unregister = useCommandStore((s) => s.unregister);
  // 최신 cmds 참조용 ref (리렌더마다 갱신)
  const ref = useRef(cmds);
  // 매 렌더 시 ref에 최신 핸들러 반영
  ref.current = cmds;

  // 제공된 함수 키만 추출·정렬 — 키 집합 변경 시에만 effect 재실행
  const availKey = (Object.keys(cmds) as CommandKey[]).filter((k) => typeof cmds[k] === "function").sort().join(",");

  useEffect(() => {
    // scrnCd 없으면 등록 생략
    if (!scrnCd) return;
    // 셸에 등록할 래퍼 객체
    const wrap: PageCommands = {};
    // availKey에 포함된 각 명령을 ref 경유 래퍼로 등록
    for (const k of availKey.split(",").filter(Boolean) as CommandKey[]) {
      wrap[k] = () => ref.current[k]?.();
    }
    // 현재 scrnCd에 래퍼 명령 등록
    register(scrnCd, wrap);
    // 언마운트·deps 변경 시 해당 scrnCd 등록 해제
    return () => unregister(scrnCd);
  }, [scrnCd, availKey, register, unregister]);
}
