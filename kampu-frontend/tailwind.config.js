/** Tailwind CSS (compilado por Angular al construir; no se usa el CDN). Solo tema claro. */
module.exports = {
  content: ['./src/**/*.{html,ts}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace']
      },
      colors: {
        // Acento de Kampu: verde oliva sobrio
        brand: {
          50: '#F5F6EF', 100: '#E9EBDC', 200: '#D3D8BA', 300: '#B5BD8E', 400: '#939C66',
          500: '#76804B', 600: '#5D673A', 700: '#4A5230', 800: '#3B4128', 900: '#2E3320'
        },
        // Amarillo pastel de la marca (detalles puntuales)
        leaf: {
          50: '#FBFAEB', 100: '#F6F3D2', 200: '#ECE6A8', 300: '#DED47A', 400: '#CBBF57',
          500: '#AFA33F', 600: '#8C8232', 700: '#6A6228'
        },
        // Neutros cálidos para fondos suaves
        sand: { 50: '#FAFAF9', 100: '#F5F5F4', 200: '#E7E5E4', 300: '#D6D3D1' },
        earth: { 50: '#FAFAF9', 100: '#F5F5F4', 300: '#D6D3D1', 400: '#A8A29E', 500: '#78716C', 600: '#57534E', 700: '#44403C' }
      },
      boxShadow: {
        soft: '0 1px 2px rgba(16, 24, 40, .04)',
        card: '0 1px 2px rgba(16, 24, 40, .04), 0 1px 3px rgba(16, 24, 40, .03)',
        lifted: '0 4px 16px -4px rgba(16, 24, 40, .10)',
        modal: '0 20px 48px -12px rgba(16, 24, 40, .22)',
        ring: '0 0 0 3px rgba(118, 128, 75, .18)'
      },
      keyframes: {
        'fade-up': { '0%': { opacity: '0', transform: 'translateY(4px)' }, '100%': { opacity: '1', transform: 'none' } },
        'pop-in': { '0%': { opacity: '0', transform: 'scale(.98)' }, '100%': { opacity: '1', transform: 'none' } },
        'fade-in': { '0%': { opacity: '0' }, '100%': { opacity: '1' } }
      },
      animation: {
        'fade-up': 'fade-up .2s ease-out both',
        'pop-in': 'pop-in .18s ease-out both',
        'fade-in': 'fade-in .15s ease-out both'
      }
    }
  },
  plugins: []
};
