"""1회성 마이그레이션과 01_sp.sql 의 프로시저 본문을 대조한다.

개발자: 박승우
일자: 2026-09-04
코멘트:
  1) 이름이 같은 CREATE OR REPLACE 본문이 글자 그대로 같은지 본다
  2) audit_sp_migration.sh 가 부른다 — 직접 부르지 않는다
  3) 다르면 종료코드 1

본문은 $$; 또는 $_$; 로 끝난다. 그 뒤의 COMMENT ON·머리주석은 대조에서 뺀다 —
같은 프로시저인데 주변 주석이 달라 어긋났다고 나오면 감시가 늑대소년이 된다.
"""
import io
import re
import sys

# CREATE OR REPLACE 한 줄 — 이름을 잡는다
HEAD = re.compile(r'CREATE OR REPLACE (?:FUNCTION|PROCEDURE) sasshaccp\.(\w+)\(')
# 달러 인용 종료 — 본문의 진짜 끝. 마지막 줄이 END$$; 라 줄머리가 아니라 줄끝으로 잡는다
TAIL = re.compile(r'(?m)^.*\$(?:_)?\$;\s*$')


def bodies(path):
    """파일에서 프로시저 본문을 이름별로 뽑는다."""
    lines = io.open(path, encoding='utf-8').read().split('\n')
    starts = [(i, m.group(1)) for i, line in enumerate(lines) if (m := HEAD.match(line))]
    out = {}
    for k, (i, name) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        body = '\n'.join(lines[i:end])
        tail = list(TAIL.finditer(body))
        if tail:
            body = body[:tail[-1].end()]
        out[name] = body.rstrip()
    return out


def main(argv):
    canon = bodies(argv[1])
    bad = 0
    for path in argv[2:]:
        for name, body in bodies(path).items():
            if name not in canon:
                print(f"  {path}: {name} 이 01_sp.sql 에 없다")
                bad += 1
            elif canon[name] != body:
                print(f"  {path}: {name} 이 01_sp.sql 과 다르다")
                bad += 1
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
