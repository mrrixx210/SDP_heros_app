import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        sdp: {
          green: "#0F8D4F",
          black: "#0B0B0B",
          stone: "#F4F4F1",
        },
      },
    },
  },
  plugins: [],
};

export default config;
