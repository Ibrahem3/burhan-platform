import type { Config } from 'tailwindcss'

export default <Config>{
  content: [
    './app/**/*.{vue,js,ts,jsx,tsx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        onyx: {
          DEFAULT: '#0a0a0a',
          50: '#1a1a1a',
          100: '#2a2a2a',
          200: '#3a3a3a',
          300: '#4a4a4a',
        },
        gold: {
          DEFAULT: '#d4af37',
          50: '#fdf6e3',
          100: '#f9eac1',
          200: '#f2d98c',
          300: '#e6c663',
          400: '#d4af37',
          500: '#b8962e',
          600: '#9c7d25',
          700: '#80641c',
          800: '#644c14',
          900: '#48350d',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        arabic: ['Noto Naskh Arabic', 'Tajawal', 'system-ui', 'sans-serif'],
      },
      backdropBlur: {
        xs: '2px',
      },
      boxShadow: {
        glass: '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
        'glass-lg': '0 16px 48px 0 rgba(0, 0, 0, 0.47)',
        glow: '0 0 20px rgba(212, 175, 55, 0.15)',
        'glow-lg': '0 0 40px rgba(212, 175, 55, 0.25)',
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-out',
        'slide-up': 'slideUp 0.5s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
}
