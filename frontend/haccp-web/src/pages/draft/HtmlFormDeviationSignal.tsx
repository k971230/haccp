/**
 * HtmlFormDeviationSignal — 지면 최하단 「이탈·개선조치 문서」 시그널.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 이 문서에 이탈·개선조치가 딸려 있는지 한 칸으로 보여주고, 없을 때만 사용자가 켤 수 있다
 *   2) 작성 5화면이 지면 아래에 공통으로 붙인다 — 화면마다 다른 표시를 두지 않는다
 *   3) 근거가 있을 때(= 부적합 판정 행 또는 이탈내용·개선조치 입력)는 자동으로 켜지고 끌 수 없다
 *
 * 저장 컬럼을 새로 두지 않는다. 켜진 상태의 정본은 이탈내용·개선조치 값이며
 * 그 값들은 기존 개선조치 테이블로 저장된다.
 *
 * PIPELINE[HF181] 이탈·개선조치 시그널
 */
// 역할 — 표시 전용 컴포넌트라 React 훅을 쓰지 않는다

export function HtmlFormDeviationSignal({
  // forced: 근거가 있어 자동으로 켜진 상태 — 부적합 행 또는 이탈·개선 입력
  forced,
  // checked: 사용자가 켠 상태
  checked,
  // onChange: 사용자 토글. 근거가 있을 때는 넘기지 않는다
  onChange,
  // editable: 작성 가능 상태
  editable,
}: {
  forced: boolean;
  checked: boolean;
  onChange?: (next: boolean) => void;
  editable: boolean;
}) {
  const on = forced || checked;
  return (
    <div
      // 지면 맨 아래 한 줄 — 인쇄에는 나가지 않는다
      className="html-form-no-print mt-2 flex items-center gap-2 border-t border-slate-200 px-2 py-2 text-xs"
    >
      <input
        // 이탈·개선조치 문서 여부
        id="html-form-deviation-signal"
        type="checkbox"
        checked={on}
        // 근거가 있을 때(= 부적합·이탈 입력) 사용자가 끄지 못하게 잠근다
        disabled={!editable || forced}
        onChange={(e) => onChange?.(e.target.checked)}
      />
      <label htmlFor="html-form-deviation-signal" className="cursor-pointer select-none">
        이탈·개선조치 문서
      </label>
      <span className={on ? "font-semibold text-rose-600" : "text-slate-500"}>
        {forced ? "있음 (부적합·이탈 내용 있음)" : on ? "있음" : "없음"}
      </span>
    </div>
  );
}
