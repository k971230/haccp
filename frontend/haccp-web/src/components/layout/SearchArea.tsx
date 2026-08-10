/**
 * SearchArea.tsx — 조회 조건 영역 (PageCard search 슬롯).
 *
 * 주요 역할:
 *     1. form submit(Enter·조회 버튼) → Page onSearch
 *     2. 날짜·콤보·체크 변경 시 Context requestSearch로 즉시 조회
 *     3. 텍스트 타이핑 중에는 자동조회하지 않음(Enter만)
 *
 * 설계 기준:
 *     - API 호출 없음 — Page의 load/run("search")에 위임
 *     - flushSync + onSearchRef — 변경 직후 이전 state로 조회되는 것 방지
 *
 * PIPELINE[HF95] UI 컴포넌트 — mes-web SearchArea와 동일 계약
 * PIPELINE[HF41, HF52] 연관 — useEditableRows / pageCommands(search)
 */
// 역할 — FormEvent·ReactNode·Context·ref·콜백
import { createContext, useCallback, useContext, useRef, type FormEvent, type ReactNode } from "react";
// 역할 — setState 직후 최신 onSearch 클로저로 조회하기 위한 동기 flush
import { flushSync } from "react-dom";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 검색 input·select 공통 스타일
import { searchInputClass } from "@/components/ui/Input";
// 역할 — MES 통일 버튼 (조회 submit)
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 검색 영역 레이아웃 클래스
import { searchActionsClass, searchFieldsClass, searchFieldsInnerClass } from "@/components/layout/pageClasses";

/** SearchArea 자식(날짜·콤보·체크)이 즉시 조회를 요청할 때 사용 */
interface SearchAreaCtx {
  /** Page onSearch와 동일 — Enter/submit·컨트롤 변경 공통 진입점 */
  requestSearch: () => void;
}

// 설명 — Provider 밖이면 no-op (SearchDateRange 단독 사용 방지용 기본값)
const SearchAreaContext = createContext<SearchAreaCtx>({ requestSearch: () => {} });

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) useSearchArea — Context에서 requestSearch 조회
 *   2) SearchDateRange·SearchSelect·SearchCheckbox onChange에서 호출
 *   3) SearchArea 밖이면 기본 no-op (조회 안 함)
 */
function useSearchArea(): SearchAreaCtx {
  return useContext(SearchAreaContext);
}

interface SearchAreaProps {
  /** 검색 조건 슬롯 — 조회만 있는 화면은 생략 가능 */
  children?: ReactNode;
  /** 우측 액션 — 보통 SearchButton(type=submit) */
  actions?: ReactNode;
  /** 조회 콜백 — Page run(() => load…, "search") */
  onSearch?: () => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 조회 조건 폼 — Enter/submit + Context requestSearch
 *   2) PageCard search 슬롯에서 사용
 *   3) 성공 시 onSearch, 실패는 Page load catch에서 msg
 */
export function SearchArea({
  // SearchArea 본문 — SearchField·DateRange·Select·Checkbox
  children,
  // 우측 액션 — SearchButton(조회)
  actions,
  // form submit·즉시조회 시 호출 — Page load/run(search)
  onSearch,
}: SearchAreaProps) {
  // 최신 onSearch 유지 — date/select 변경 직후 이전 클로저로 조회되는 것 방지
  const onSearchRef = useRef(onSearch);
  onSearchRef.current = onSearch;
  // 안정 참조 — 자식 onChange가 매 렌더 새 함수를 잡지 않도록
  const requestSearch = useCallback(() => {
    onSearchRef.current?.();
  }, []);

  // form submit — Enter·SearchButton — 기본 새로고침 방지 후 조회
  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    requestSearch();
  };
  // Context 값 — 자식 즉시조회와 submit이 동일 진입점
  const ctx: SearchAreaCtx = { requestSearch };
  return (
    <SearchAreaContext.Provider value={ctx}>
      <form className="m-0" onSubmit={onSubmit}>
        <section className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className={searchFieldsClass}>
            {children != null ? (
              <div className={searchFieldsInnerClass}>{children}</div>
            ) : (
              <div className={searchFieldsInnerClass} />
            )}
            {actions && <div className={searchActionsClass}>{actions}</div>}
          </div>
        </section>
      </form>
    </SearchAreaContext.Provider>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 페이지 상단 타이틀·메시지 영역
 *   2) Page 최상단에서 호출
 *   3) 성공 시 제목·msg 표시
 */
export function PageHead({
  // 화면 제목 — PageHead 좌측 h2
  title,
  // 오류·안내 메시지 — 없으면 미표시
  msg,
  // 제목·메시지 사이 추가 슬롯
  extra,
}: { title: string; msg?: string | null; extra?: ReactNode }) {
  return (
    <div className="mb-0.5 flex shrink-0 flex-wrap items-center justify-between gap-2">
      <h2 className="m-0 text-base font-bold text-black">
        {title}
      </h2>
      {extra}
      {msg && <span className="text-xs font-medium text-rose-600">{msg}</span>}
    </div>
  );
}

interface SearchFieldProps {
  label: string;
  children: ReactNode;
  required?: boolean;
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 검색 조건 라벨+입력 필드 래퍼
 *   2) SearchArea 자식으로 사용
 *   3) 성공 시 라벨·컨트롤 렌더
 */
export function SearchField({
  // 조건 라벨 — required면 * 표시
  label,
  // 입력 컨트롤 슬롯(input/select 등)
  children,
  // 필수 표시 여부 — true일 때(= 라벨에 *)
  required,
  // 추가 className
  className,
}: SearchFieldProps) {
  return (
    <label className={cn("flex min-w-0 flex-col gap-0.5", className)}>
      <span className={cn("text-[11px] font-bold text-neutral-700", required && "after:ml-0.5 after:text-rose-600 after:content-['*']")}>
        {label}
      </span>
      {children}
    </label>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 기간 검색 From~To — 변경 시 즉시 조회
 *   2) SearchArea 안에서만 사용(Context 필요)
 *   3) flushSync 후 requestSearch — 이전 날짜로 load 방지
 */
export function SearchDateRange({
  // 시작일 YYYY-MM-DD — date input value
  from,
  // 종료일 YYYY-MM-DD — date input value
  to,
  // 시작일 변경 — Page search state setter
  onFrom,
  // 종료일 변경 — Page search state setter
  onTo,
  // 기간 필드 라벨 — 기본 "기간"
  label = "기간",
}: {
  from: string; to: string; onFrom: (v: string) => void; onTo: (v: string) => void;
  label?: string;
}) {
  // SearchArea Context — 즉시 조회
  const { requestSearch } = useSearchArea();
  return (
    <SearchField label={label}>
      <div className="flex items-center gap-1.5">
        <input
          // HTML date — 시작일
          type="date"
          // 검색 input 공통 스타일
          className={searchInputClass}
          // 제어 값 — from
          value={from}
          // 변경 시 state 반영 후 즉시 조회
          onChange={(e) => {
            const v = e.target.value;
            // state 반영을 동기화한 뒤 조회 — 이전 날짜로 load 되는 것 방지
            flushSync(() => onFrom(v));
            requestSearch();
          }}
        />
        <span className="text-slate-400">~</span>
        <input
          // HTML date — 종료일
          type="date"
          className={searchInputClass}
          value={to}
          onChange={(e) => {
            const v = e.target.value;
            flushSync(() => onTo(v));
            requestSearch();
          }}
        />
      </div>
    </SearchField>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 검색 콤보(select) — 변경 시 즉시 조회
 *   2) SearchArea 안 raw select 대체(Client·Bom 등)
 *   3) flushSync 후 requestSearch
 */
export function SearchSelect({
  // 콤보 라벨
  label,
  // 선택 값 — 제어 컴포넌트
  value,
  // 값 변경 — Page setter (예: setClientGbn)
  onChange,
  // option 목록 슬롯
  children,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  children: ReactNode;
}) {
  const { requestSearch } = useSearchArea();
  return (
    <SearchField label={label}>
      <select
        // 검색 select 공통 스타일
        className={searchInputClass}
        // 제어 값
        value={value}
        // 변경 시 state + 즉시 조회
        onChange={(e) => {
          const v = e.target.value;
          flushSync(() => onChange(v));
          requestSearch();
        }}
      >
        {children}
      </select>
    </SearchField>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 검색 체크박스 — 변경 시 즉시 조회
 *   2) SearchArea 안에서 사용(예: 미출하만)
 *   3) flushSync 후 requestSearch
 */
export function SearchCheckbox({
  // 체크박스 옆 라벨
  label,
  // 체크 여부 — 제어 컴포넌트
  checked,
  // 체크 변경 — Page boolean setter
  onChange,
}: {
  label: string; checked: boolean; onChange: (v: boolean) => void;
}) {
  const { requestSearch } = useSearchArea();
  return (
    <label className="flex items-end gap-1.5 pb-0.5 text-mes-ui text-slate-700">
      <input
        type="checkbox"
        className="rounded border-slate-300 text-brand-700 focus:ring-brand-100"
        checked={checked}
        onChange={(e) => {
          const v = e.target.checked;
          flushSync(() => onChange(v));
          requestSearch();
        }}
      />
      <span>{label}</span>
    </label>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 검색 카드 내 조회 버튼 (type=submit)
 *   2) SearchArea actions에 배치
 *   3) 클릭 시 form submit → onSearch
 */
export function SearchButton({
  // 버튼 문구 — 기본 "조회"
  label = "조회",
  // busy 시 스피너 — isBusy("search")
  loading,
}: { label?: string; loading?: boolean }) {
  return (
    <MesButton
      // form submit — SearchArea onSubmit
      type="submit"
      // 조회 variant
      variant="search"
      // 검색 아이콘
      icon="search"
      // 조회 중 스피너
      loading={loading}
    >
      {label}
    </MesButton>
  );
}

export { searchInputClass };
