import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/** 로컬 전용 — 단일 SQL 파일을 JDBC simple 모드로 적용한다. git 미포함. */
public class ApplyOneSql {
    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("usage: ApplyOneSql <file.sql> [verify.sql]");
            System.exit(2);
        }
        Path sqlFile = Path.of(args[0]);
        Map<String, String> env = loadDotEnv(Path.of("backend/haccp-api/.env"));
        String host = first(env, "DB_HOST", "PGHOST");
        String port = first(env, "DB_PORT", "PGPORT");
        if (port == null || port.isBlank()) port = "5432";
        String db = first(env, "DB_NAME", "PGDATABASE");
        if (db == null || db.isBlank()) db = "sasshaccp";
        String user = first(env, "DB_USERNAME", "PGUSER");
        String pass = first(env, "DB_PASSWORD", "PGPASSWORD");
        String url = "jdbc:postgresql://" + host + ":" + port + "/" + db
                + "?currentSchema=sasshaccp&preferQueryMode=simple";
        Properties props = new Properties();
        props.setProperty("user", user);
        props.setProperty("password", pass);
        System.out.println("apply " + sqlFile.getFileName() + " -> " + host + "/" + db);
        String sql = Files.readString(sqlFile, StandardCharsets.UTF_8);
        List<String> stmts = splitSql(sql);
        try (Connection c = DriverManager.getConnection(url, props)) {
            c.setAutoCommit(false);
            try (Statement st = c.createStatement()) {
                for (String stmt : stmts) {
                    st.execute(stmt);
                }
            }
            c.commit();
            if (args.length >= 2) {
                try (Statement st = c.createStatement();
                     ResultSet rs = st.executeQuery(Files.readString(Path.of(args[1]), StandardCharsets.UTF_8))) {
                    int cols = rs.getMetaData().getColumnCount();
                    while (rs.next()) {
                        StringBuilder line = new StringBuilder();
                        for (int i = 1; i <= cols; i++) {
                            if (i > 1) line.append('\t');
                            line.append(rs.getString(i));
                        }
                        System.out.println(line);
                    }
                }
            }
        }
        System.out.println("ok statements=" + stmts.size());
    }

    static Map<String, String> loadDotEnv(Path file) throws Exception {
        Map<String, String> map = new LinkedHashMap<>();
        if (!Files.isRegularFile(file)) return map;
        for (String raw : Files.readAllLines(file, StandardCharsets.UTF_8)) {
            String line = raw.trim();
            if (line.isEmpty() || line.startsWith("#")) continue;
            int eq = line.indexOf('=');
            if (eq <= 0) continue;
            String key = line.substring(0, eq).trim();
            String val = line.substring(eq + 1).trim();
            if (val.length() >= 2 && ((val.startsWith("\"") && val.endsWith("\""))
                    || (val.startsWith("'") && val.endsWith("'")))) {
                val = val.substring(1, val.length() - 1);
            }
            map.put(key, val);
        }
        return map;
    }

    static String first(Map<String, String> env, String a, String b) {
        String v = env.get(a);
        if (v != null && !v.isBlank()) return v;
        v = env.get(b);
        if (v != null && !v.isBlank()) return v;
        v = System.getenv(a);
        if (v != null && !v.isBlank()) return v;
        return System.getenv(b);
    }

    static List<String> splitSql(String sql) {
        List<String> out = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        int i = 0;
        int n = sql.length();
        while (i < n) {
            char ch = sql.charAt(i);
            if (ch == '-' && i + 1 < n && sql.charAt(i + 1) == '-') {
                int e = sql.indexOf('\n', i);
                if (e < 0) e = n - 1;
                i = e + 1;
                continue;
            }
            if (ch == '/' && i + 1 < n && sql.charAt(i + 1) == '*') {
                int e = sql.indexOf("*/", i + 2);
                if (e < 0) throw new IllegalArgumentException("unclosed block comment");
                i = e + 2;
                continue;
            }
            if (ch == '$') {
                int tagEnd = dollarTagEnd(sql, i);
                if (tagEnd >= 0) {
                    String tag = sql.substring(i, tagEnd + 1);
                    int close = sql.indexOf(tag, tagEnd + 1);
                    if (close < 0) throw new IllegalArgumentException("unclosed dollar quote " + tag);
                    cur.append(sql, i, close + tag.length());
                    i = close + tag.length();
                    continue;
                }
            }
            if (ch == '\'') {
                cur.append(ch);
                i++;
                while (i < n) {
                    char q = sql.charAt(i);
                    cur.append(q);
                    i++;
                    if (q == '\'' && i < n && sql.charAt(i) == '\'') {
                        cur.append('\'');
                        i++;
                        continue;
                    }
                    if (q == '\'') break;
                }
                continue;
            }
            if (ch == ';') {
                String stmt = cur.toString().trim();
                if (!stmt.isEmpty()) out.add(stmt);
                cur.setLength(0);
                i++;
                continue;
            }
            cur.append(ch);
            i++;
        }
        String tail = cur.toString().trim();
        if (!tail.isEmpty()) out.add(tail);
        return out;
    }

    static int dollarTagEnd(String s, int start) {
        int i = start + 1;
        while (i < s.length()) {
            char c = s.charAt(i);
            if (c == '$') return i;
            if (!(Character.isLetterOrDigit(c) || c == '_')) return -1;
            i++;
        }
        return -1;
    }
}
