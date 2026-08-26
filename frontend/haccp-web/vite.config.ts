// vite.config.ts — haccp-web 개발 서버·빌드 설정
//
// 개발자: 박승우
// 일자: 2026-08-26
// 코멘트:
//   1) 로컬 Vite 포트 4173 — mes-web(5173)과 구분. server.port 는 npm run dev 전용(배포 무관)
//   2) 로컬·운영 모두 VITE_BASE=/haccp/ — Apache Path 와 basename 정합. 루트 / 는 /haccp/ 로 보낸다
//   3) Chrome origin 루트 /favicon.ico 는 public(base 아래)에 없어서 /haccp/logo2.svg 로 넘긴다
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
      // DEV에서 %BASE_URL%logo2.svg 가 /haccp/haccp/ 로 이중 접두되는 것을 빌드 산출물에서 고친다
      transformIndexHtml: {
        order: "post",
        handler(html) {
          const base = (process.env.VITE_BASE || "/haccp/").replace(/\/$/, "");
          return html.replaceAll(`${base}${base}/logo2.svg`, `${base}/logo2.svg`);
        },
      },
      configureServer(server) {
        // Vite base — trailing slash 제거. public 자산은 이 접두 아래에만 있다
        const base = (process.env.VITE_BASE || "/haccp/").replace(/\/$/, "");
        server.middlewares.use((req, res, next) => {
          const url = req.url?.split("?")[0] ?? "";
          // / 또는 /index.html 일 때(= 앱 밖 루트) /haccp/ 로 보낸다
          if (url === "/" || url === "/index.html") {
            res.statusCode = 302;
            res.setHeader("Location", `${base}/`);
            res.end();
            return;
          }
          // Chrome origin 루트 /favicon.ico — public 은 base 아래만 있다
          if (url === "/favicon.ico") {
            req.url = `${base}/logo2.svg`;
          }
          // DEV HTML 이중 접두 — SPA fallback 이 index.html 을 아이콘으로 주는 것을 막는다
          if (url === `${base}${base}/logo2.svg`) {
            req.url = `${base}/logo2.svg`;
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
