import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        wevix: {
          black: "#0a0a0a",
          charcoal: "#1c1c1e",
          white: "#fafaf9",
          beige: "#e8e2d6",
          gold: "#c9a86a",
          "gold-light": "#e3cd9a",
        },
      },
      fontFamily: {
        display: ["var(--font-display)", "serif"],
        sans: ["var(--font-sans)", "sans-serif"],
      },
      animation: {
        "fade-in": "fadeIn 0.8s ease-out forwards",
        "fade-in-up": "fadeInUp 0.9s ease-out forwards",
        shimmer: "shimmer 2s infinite linear",
        "logo-reveal": "logoReveal 1.4s cubic-bezier(0.16, 1, 0.3, 1) forwards",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        fadeInUp: {
          "0%": { opacity: "0", transform: "translateY(24px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        shimmer: {
          "0%": { backgroundPosition: "-1000px 0" },
          "100%": { backgroundPosition: "1000px 0" },
        },
        logoReveal: {
          "0%": { opacity: "0", letterSpacing: "0.5em", filter: "blur(8px)" },
          "100%": { opacity: "1", letterSpacing: "0.05em", filter: "blur(0)" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
