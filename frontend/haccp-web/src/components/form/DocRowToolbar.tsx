/**
 * DocRowToolbar — 문서 표 행 추가·삭제 도구.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) PDF형 본문 표 하단에 행 추가/삭제 버튼을 공통으로 둔다
 *   2) 삭제 가능 여부는 소유 화면이 판단한다(표준행 금지 등)
 *   3) MesEditableGrid 크롬은 쓰지 않는다
 *
 * PIPELINE[HF125] 문서 행 도구
 * PIPELINE[HF120] 연관 모듈
 */
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — className
import { cn } from "@/lib/cn";

export interface DocRowToolbarProps {
  // 행 추가
  onAdd: () => void;
  // 행 삭제 — 없으면 삭제 버튼 숨김
  onRemove?: () => void;
  // 추가 가능
  canAdd?: boolean;
  // 삭제 가능
  canRemove?: boolean;
  // 추가 라벨
  addLabel?: string;
  // 삭제 라벨
  removeLabel?: string;
  // 클래스
  className?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 행 추가·삭제 버튼을 렌더링한다
 *   2) 본문 표 바로 아래에서 호출한다
 *   3) can* false면 해당 버튼을 끈다
 */
export function DocRowToolbar({
  onAdd,
  onRemove,
  canAdd = true,
  canRemove = true,
  addLabel = "행 추가",
  removeLabel = "행 삭제",
  className,
}: DocRowToolbarProps) {
  return (
    <div className={cn("mt-2 flex flex-wrap gap-2", className)}>
      <MesButton variant="secondary" size="sm" disabled={!canAdd} onClick={onAdd}>
        {addLabel}
      </MesButton>
      {onRemove ? (
        <MesButton variant="danger" size="sm" disabled={!canRemove} onClick={onRemove}>
          {removeLabel}
        </MesButton>
      ) : null}
    </div>
  );
}
