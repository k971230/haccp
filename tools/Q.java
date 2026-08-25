import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Statement;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;

/** 로컬 전용 — SQL 한 덩어리를 실행하고 결과를 표로 찍는다. git 미포함. */
public class Q {
    public static void main(String[] args) throws Exception {
        String sql = args.length > 0 && args[0].startsWith("@")
                ? Files.readString(Path.of(args[0].substring(1)), StandardCharsets.UTF_8)
                : String.join(" ", args);
        Map<String, String> env = loadDotEnv(Path.of("backend/haccp-api/.env"));
        String url = "jdbc:postgresql://" + env.get("DB_HOST") + ":" + env.getOrDefault("DB_PORT", "5432")
                + "/" + env.getOrDefault("DB_NAME", "sasshaccp")
                + "?currentSchema=sasshaccp&preferQueryMode=simple";
        Class.forName("org.postgresql.Driver");
        Properties p = new Properties();
        p.setProperty("user", env.get("DB_USERNAME"));
        p.setProperty("password", env.get("DB_PASSWORD"));
        try (Connection c = DriverManager.getConnection(url, p); Statement st = c.createStatement()) {
            boolean hasRs = st.execute(sql);
            int n = 0;
            do {
                if (hasRs) {
                    try (ResultSet rs = st.getResultSet()) {
                        print(rs);
                    }
                } else {
                    int u = st.getUpdateCount();
                    if (u >= 0) System.out.println("(" + u + " rows affected)");
                }
                n++;
                hasRs = st.getMoreResults();
            } while (hasRs || st.getUpdateCount() != -1);
            if (n == 0) System.out.println("(no result)");
        }
    }

    private static void print(ResultSet rs) throws Exception {
        ResultSetMetaData m = rs.getMetaData();
        int cols = m.getColumnCount();
        StringBuilder head = new StringBuilder();
        for (int i = 1; i <= cols; i++) head.append(m.getColumnLabel(i)).append(i < cols ? " | " : "");
        System.out.println(head);
        System.out.println("-".repeat(Math.min(head.length(), 200)));
        int rows = 0;
        while (rs.next()) {
            StringBuilder sb = new StringBuilder();
            for (int i = 1; i <= cols; i++) {
                String v = rs.getString(i);
                if (v != null && v.length() > 90) v = v.substring(0, 90) + "...";
                sb.append(v).append(i < cols ? " | " : "");
            }
            System.out.println(sb);
            rows++;
        }
        System.out.println("(" + rows + " rows)");
    }

    private static Map<String, String> loadDotEnv(Path f) throws Exception {
        Map<String, String> m = new LinkedHashMap<>();
        for (String line : Files.readAllLines(f, StandardCharsets.UTF_8)) {
            String s = line.trim();
            if (s.isEmpty() || s.startsWith("#")) continue;
            int eq = s.indexOf('=');
            if (eq <= 0) continue;
            m.put(s.substring(0, eq).trim(), s.substring(eq + 1).trim());
        }
        return m;
    }
}
