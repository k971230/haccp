// vite.config.ts — haccp-web 개발 서버·빌드 설정
//
// 개발자: 박승우
// 일자: 2026-08-20
// 코멘트:
//   1) 로컬 Vite 포트 4173 — mes-web(5173)과 구분. server.port 는 npm run dev 전용(배포 무관)
//   2) 로컬·운영 모두 VITE_BASE=/haccp/ — Apache Path 와 basename 정합. 루트 / 는 /haccp/ 로 보낸다
//   3) /rhwp 는 edwardkim.github.io 스튜디오 프록시 — 동일출처로 도구상자(#icon-toolbar)를 접기 위함
import react from "@vitejs/plugin-react";
import path from "path";
import { fileURLToPath } from "url";
import { defineConfig } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  // 로컬·운영 모두 Path /haccp/. 이미지 빌드 ARG VITE_BASE=/haccp/ 와 동일
  base: process.env.VITE_BASE || "/haccp/",
  plugins: [
    react(),
    {
      // 로컬 4173 루트(/) 접속을 앱 basename 으로 보낸다
      name: "redirect-root-to-haccp-base",
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          const url = req.url?.split("?")[0] ?? "";
          // / 또는 /index.html 일 때(= 앱 밖 루트) /haccp/ 로 보낸다
          if (url === "/" || url === "/index.html") {
            res.statusCode = 302;
            res.setHeader("Location", "/haccp/");
            res.end();
            return;
          }
          next();
        });
      },
    },
  ],
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
  server: {
    // mes-web(5173)과 구분 — CORS(CORS_ALLOWED_ORIGINS)도 http://localhost:4173 과 맞춘다
    // strictPort true: 점유 시 다른 포트로 조용히 빠지지 않게 해 Origin/CORS 불일치를 막는다
    port: 4173,
    host: "localhost",
    strictPort: true,
    // rhwp-studio 동일출처 프록시 — createEditor studioUrl=/rhwp/ 후 iframe contentDocument로 도구상자 접기
    // GitHub Pages 배포본 경로가 /rhwp/* 이므로 rewrite 없이 origin만 바꾼다
    proxy: {
      "/rhwp": {
        target: "https://edwardkim.github.io",
        changeOrigin: true,
        secure: true,
      },
    },
  },
  test: {
    globals: true,
    environment: "jsdom",
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
  },
});
