/** 그리드 헤더용 행추가·저장·삭제 버튼. 
 * PIPELINE[F84] 그리드 CRUD 버튼
 * PIPELINE[F90, F52] 연관 모듈
 */
// 역할 — ReactNode 타입 — children 슬롯
import type { ReactNode } from "react";
// 역할 — MES 통일 버튼 컴포넌트
import { MesButton } from "@/components/ui/MesButton";

// 설명 — useAsyncAction.run 시그니처 — save/del 중복 클릭 방지
type RunFn = <T>(fn: () => Promise<T>, key: string) => Promise<T | undefined>;

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 그리드 패널 헤더 CRUD 버튼 묶음 — 행추가·저장·삭제
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 그리드 패널 헤더 CRUD 버튼 묶음 — 행추가·저장·삭제
export function GridCrudButtons({
  // 행추가 클릭 핸들러
  // 없으면 행추가 버튼 미표시
  onAdd,
  // 저장 클릭 핸들러
  // run이 있으면 key="save"로 래핑해 busy 표시
  onSave,
  // 삭제 클릭 핸들러
  // run이 있으면 key="del"로 래핑해 busy 표시
  onDel,
  // 행추가 버튼 표시 문구
  // 기본 "행추가"
  addLabel = "행추가",
  // 저장 버튼 표시 문구
  // 기본 "저장"
  saveLabel = "저장",
  // 삭제 버튼 표시 문구
  // 기본 "삭제"
  delLabel = "삭제",
  // 버튼별 로딩 상태(add/save/del)
  // true인 키의 MesButton에 loading 전달
  busy,
  // useAsyncAction.run — key 단위 중복 실행 방지
  // 없으면 onSave/onDel을 직접 호출
  run,
  // 자식 노드(라벨·슬롯 콘텐츠)
  // 버튼 텍스트 또는 레이아웃 본문
  children,
}: {
  onAdd?: () => void;
  onSave?: () => void | Promise<void>;
  onDel?: () => void | Promise<void>;
  addLabel?: string;
  saveLabel?: string;
  delLabel?: string;
  busy?: { add?: boolean; save?: boolean; del?: boolean };
  run?: RunFn;
  children?: ReactNode;
}) {
  // run 훅이 있으면 key 단위로 비동기 래핑, 없으면 직접 호출
  const wrap = (fn?: () => void | Promise<void>, key?: string) => {
    if (!fn) return undefined;
    if (run && key) return () => { void run(async () => { await fn(); }, key); };
    return () => { void fn(); };
  };

  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {onAdd && (
        <MesButton variant="add" size="sm" icon="plus" loading={busy?.add} onClick={onAdd}>
          {addLabel}
        </MesButton>
      )}
      {children}
      {onSave && (
        <MesButton variant="save" size="sm" icon="save" loading={busy?.save} onClick={wrap(onSave, "save")}>
          {saveLabel}
        </MesButton>
      )}
      {onDel && (
        <MesButton variant="danger" size="sm" icon="trash" loading={busy?.del} onClick={wrap(onDel, "del")}>
          {delLabel}
        </MesButton>
      )}
    </div>
  );
}
