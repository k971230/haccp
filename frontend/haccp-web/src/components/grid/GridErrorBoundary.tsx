/**
 * GridErrorBoundary — 그리드 런타임 오류 격리. 다시 시도 시 내부 key 리셋.
 
 * PIPELINE[F167]
 */
// 역할 — React 클래스 컴포넌트·ErrorInfo·ReactNode
import { Component, type ErrorInfo, type ReactNode } from "react";
// 역할 — 다시 시도 버튼
import { MesButton } from "@/components/ui/MesButton";

interface GridErrorBoundaryProps {
  children: ReactNode;
  label?: string;
}

interface GridErrorBoundaryState {
  error: Error | null;
  resetKey: number;
}

// 설명 — 그리드 런타임 오류 격리 — 오류 시 fallback UI·resetKey로 재마운트
export class GridErrorBoundary extends Component<GridErrorBoundaryProps, GridErrorBoundaryState> {
  state: GridErrorBoundaryState = { error: null, resetKey: 0 };

// 설명 — 오류 발생 시 error 상태 갱신
  static getDerivedStateFromError(error: Error): Partial<GridErrorBoundaryState> {
    return { error };
  }

// 설명 — 서버 로그용 오류·스택 기록
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(`[GridErrorBoundary${this.props.label ? `:${this.props.label}` : ""}]`, error, info.componentStack);
  }

  // resetKey 증가로 children 재마운트
  private retry = () => {
    this.setState((s) => ({ error: null, resetKey: s.resetKey + 1 }));
  };

  render() {
    if (this.state.error) {
      return (
        <div className="flex min-h-[120px] flex-col items-center justify-center gap-2 border border-rose-200 bg-rose-50/60 px-4 py-6 text-mes-ui text-slate-700">
          <p className="font-bold text-rose-700">그리드를 표시하는 중 오류가 발생했습니다.</p>
          <p className="text-[11px] text-slate-500">데이터는 유지됩니다. 다시 시도하거나 화면을 새로고침하세요.</p>
          <MesButton size="sm" variant="secondary" onClick={this.retry}>
            다시 시도
          </MesButton>
        </div>
      );
    }
    return <div key={this.state.resetKey} className="contents">{this.props.children}</div>;
  }
}
