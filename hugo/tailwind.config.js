/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class', // important so that dark: utilities work on the .dark class

  content: [
    './layouts/**/*.html',
    '../../layouts/**/*.html',
    '../**/layouts/**/*.html',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      colors: {
       primary: {
          50:  '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          DEFAULT: '#2563eb', // (600) as default if you use `bg-primary, text-primary, etc.`
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
          950: '#172554',
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
  ],
  // Ensure Tailwind doesn't conflict with the lazy loading and responsive image features
  safelist: ['lazy-load', 'lazy-load-bg', 'lazy-load-video', 'picture', 'source', 'webp', 'srcset'],
};
