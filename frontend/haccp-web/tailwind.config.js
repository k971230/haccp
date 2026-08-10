/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        canvas: "#F8FAFC",
        surface: "#FFFFFF",
        "grid-body": "#F7F9FB",
        brand: {
          50: "#EEF4FB",
          100: "#DCE8F5",
          200: "#B8D0E8",
          300: "#8BB0D4",
          400: "#5A8AB8",
          500: "#3D6A9A",
          600: "#2D5278",
          700: "#1E3A5F",
          800: "#17304F",
          900: "#1E3A5F",
          950: "#122840",
        },
        "grid-head": "#F8FAFC",
        "grid-head-text": "#475569",
        "grid-border": "#E2E8F0",
        danger: {
          DEFAULT: "#B42318",
          hover: "#FEF3F2",
        },
        navy: {
          800: "#1d2939",
          900: "#101828",
        },
        /* rgb(95,106,245) 기준 — HSL 파생(hover L↓, muted S↓ L↑) */
        primary: {
          DEFAULT: "#5F6AF5",
          hover: "#4E5AE8",
          muted: "#8B96F8",
          deep: "#3D4AD4",
        },
        sidebar: {
          bg: "#F3F4F6",
          text: "#000000",
          muted: "#6B7280",
          border: "#E5E7EB",
        },
      },
      fontSize: {
        "mes-ui": ["12px", { lineHeight: "1.4" }],
        "mes-title": ["14px", { lineHeight: "1.4" }],
      },
      height: {
        "mes-row": "26px",
        "mes-head": "30px",
        "mes-input": "28px",
        "mes-touch": "40px",
      },
      minHeight: {
        "mes-touch": "40px",
        "mes-head": "30px",
      },
      borderRadius: {
        mes: "6px",
        "mes-lg": "8px",
        "mes-xl": "12px",
      },
    },
  },
  plugins: [],
};
