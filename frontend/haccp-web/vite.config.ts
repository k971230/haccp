// vite.config.ts — haccp-web 개발 서버·빌드 설정
//
// 개발자: 박승우
// 일자: 2026-08-06
// 코멘트:
//   1) mes-web과 같은 구성이며, 포트만 5174로 바꿨다 — 두 프론트를 동시에 띄워도 충돌하지 않는다
//   2) @ 별칭은 src 루트를 가리킨다. tsconfig.json paths와 반드시 같은 값을 유지해야 한다
//   3) /rhwp 는 edwardkim.github.io 스튜디오 프록시 — 동일출처로 도구상자(#icon-toolbar)를 접기 위함
import react from "@vitejs/plugin-react";
import path from "path";
import { fileURLToPath } from "url";
import { defineConfig } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
  server: {
    // mes-web(5173)과 구분 — haccp-api CORS 허용 출처도 5174로 맞춰져 있다
    port: 5174,
    host: "localhost",
    strictPort: false,
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
