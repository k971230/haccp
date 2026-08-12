/**
 * treeFilter — 좌측 트리 결과 내 검색(부분일치·조상 유지).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 메뉴·부서·권한그룹 트리 상단 필터에 공통으로 쓴다
 *   2) 매칭 노드와 조상만 남기고, 펼칠 키 집합을 함께 반환한다
 *   3) API 호출 없이 FE에서만 좁힌다
 *
 * PIPELINE[HF92] 트리 필터
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) q가 비면 원본 트리와 빈 openKeys를 반환한다
 *   2) id·label 부분일치(대소문자 무시)로 자손·자기 매칭 시 경로 유지
 *   3) 메뉴·부서·권한 트리 검색에서 호출한다
 */
export function filterTreeByQuery<T extends { children: T[] }>(
  // 원본 루트 목록
  roots: T[],
  // 검색어 — 빈값이면 필터 없음
  query: string,
  // 노드 고유 키 — 펼침·매칭
  getId: (node: T) => string,
  // 표시명 — 부분일치
  getLabel: (node: T) => string,
): { nodes: T[]; openKeys: Set<string> } {
  const q = query.trim().toLowerCase();
  if (!q) return { nodes: roots, openKeys: new Set() };

  const openKeys = new Set<string>();

  const walk = (node: T): T | null => {
    const id = getId(node);
    const label = getLabel(node);
    const selfHit =
      id.toLowerCase().includes(q) || label.toLowerCase().includes(q);
    const keptChildren: T[] = [];
    for (const child of node.children) {
      const next = walk(child);
      if (next) keptChildren.push(next);
    }
    if (!selfHit && keptChildren.length === 0) return null;
    if (keptChildren.length > 0 || selfHit) openKeys.add(id);
    return { ...node, children: keptChildren };
  };

  const nodes: T[] = [];
  for (const root of roots) {
    const next = walk(root);
    if (next) nodes.push(next);
  }
  return { nodes, openKeys };
}
