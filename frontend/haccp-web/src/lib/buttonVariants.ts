/**
 * buttonVariants — 버튼 variant x size 스타일 조합표.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) MesButton이 쓰는 Tailwind 클래스 조합을 한곳에 모아 버튼 색이 화면마다 갈리지 않게 한다
 *   2) 색은 연한 틴트를 기본으로 한다 — 한 화면에 버튼이 여러 개 놓여도 시야를 어지럽히지 않는다
 *   3) React 의존이 없는 순수 스타일 정의다. 크기는 sm·md 두 가지만 둔다(터치PC 없음)
 *
 * PIPELINE[HF37] 공통 모듈
 */
// 역할 — variant x size 조합 클래스 생성
import { cva } from "class-variance-authority";

/** OBT 보조 — 투명, #ccc (필터·열 등) */
const obtnSoft =
  "border border-[#ccc] bg-transparent font-normal tracking-normal text-black shadow-none hover:bg-black/[0.04] [&_svg]:text-black";

/** OBT 스타일 — 투명 배경, #ccc 테두리 */
const obtn =
  "border border-[#ccc] bg-transparent font-bold tracking-normal text-black shadow-none hover:bg-black/[0.04] [&_svg]:text-black";

/** 연한 틴트 — border-200 / bg / hover 패턴 */
const tinted = (border: string, bg: string, text: string, hover: string, svg: string) =>
  `border ${border} ${bg} font-bold tracking-normal ${text} shadow-none ${hover} ${svg}`;

/** 조회 — 그리드 편집가능 활성(blue-100)과 동일 */
const searchTint = tinted(
  "border-blue-200",
  "bg-blue-100",
  "text-blue-700",
  "hover:bg-blue-200/80",
  "[&_svg]:text-blue-700",
);

const addTint = tinted(
  "border-amber-200",
  "bg-amber-50",
  "text-amber-700",
  "hover:bg-amber-100",
  "[&_svg]:text-amber-700",
);
const saveTint = tinted(
  "border-blue-200",
  "bg-blue-50",
  "text-blue-600",
  "hover:bg-blue-100",
  "[&_svg]:text-blue-600",
);
const dangerTint = tinted(
  "border-red-200",
  "bg-red-50",
  "text-red-600",
  "hover:bg-red-100",
  "[&_svg]:text-red-600",
);
/** CSV보내기 — 셸 단축키 대상(.mes-sec-active) 그리드 헤더 틴트와 동일 (emerald) */
const excelTint = tinted(
  "border-emerald-200",
  "bg-emerald-50",
  "text-emerald-700",
  "hover:bg-emerald-100",
  "[&_svg]:text-emerald-700",
);
/** 파일 다운로드 — 행추가(amber)·저장(blue)·삭제(red)·CSV(emerald)와 구분하는 indigo 계열 */
const downloadTint = tinted(
  "border-indigo-200",
  "bg-indigo-50",
  "text-indigo-700",
  "hover:bg-indigo-100",
  "[&_svg]:text-indigo-700",
);

/** 공통 버튼 스타일 — MesButton 전용. 화면에서 직접 호출하지 않는다 */
export const buttonVariants = cva(
  "inline-flex items-center justify-center gap-1 rounded-[2px] tracking-normal transition disabled:cursor-not-allowed disabled:opacity-50",
  {
    variants: {
      variant: {
        search: searchTint,
        save: saveTint,
        primary: saveTint,
        add: addTint,
        secondary: obtnSoft,
        edit: obtn,
        danger: dangerTint,
        dangerConfirm: "border border-danger bg-danger font-bold tracking-normal text-white shadow-none hover:bg-red-800",
        excel: excelTint,
        download: downloadTint,
        ghost: "border border-transparent bg-transparent font-bold tracking-normal text-black hover:bg-black/[0.04] [&_svg]:text-black",
      },
      size: {
        // 그리드 툴바 — 행 높이에 맞춰 낮게
        sm: "h-7 px-2.5 text-xs",
        // 일반 — 조회 조건 영역·모달 하단
        md: "h-8 px-3 text-mes-ui",
      },
    },
    defaultVariants: {
      variant: "secondary",
      size: "md",
    },
  },
);
