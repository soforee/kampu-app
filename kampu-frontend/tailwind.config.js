/**
 * Tailwind CSS (compilado por Angular; no se usa el CDN). Solo tema claro.
 *
 * Identidad visual: todos los colores salen del logotipo de Kampu.
 *   - #4B5B1D  verde oliva del isotipo y del nombre  -> brand-600 (color principal)
 *   - #C4BD45  verde lima de la hoja                  -> leaf-400  (acento, solo detalles)
 *   - #FDF8E6  crema de la versión sobre fondo oscuro -> base de los fondos claros
 * Las demás tonalidades son mezclas de esos colores con blanco o negro (no se usan colores ajenos a la marca).
 * Los nombres estándar de Tailwind se redefinen con la paleta de la marca, para que todo el sistema la use:
 *   zinc   -> neutros cálidos (texto, bordes y fondos)
 *   emerald-> oliva (estados correctos: confirmado, pagado, activo)
 *   amber  -> dorado de la hoja (avisos y pendientes)
 *   rose   -> terracota apagado (errores y acciones peligrosas)
 *   sky / violet -> oliva claro y neutro (estados intermedios)
 */
const brand = {
  50: '#F4F6E4', 100: '#E7ECC9', 200: '#CED89C', 300: '#AFBF68', 400: '#8B9E3F',
  500: '#6B7E2B', 600: '#4B5B1D', 700: '#3F4C18', 800: '#333D14', 900: '#262E0F', 950: '#1A200A'
};
const leaf = {
  50: '#FAF9E3', 100: '#F3F0C2', 200: '#E6E08F', 300: '#D7D068', 400: '#C4BD45',
  500: '#A9A232', 600: '#878126', 700: '#666120', 800: '#4F4B19', 900: '#3D3A14', 950: '#29270D'
};
// Neutros cálidos: grises con un toque del crema y del oliva de la marca
const neutro = {
  50: '#FAF9F4', 100: '#F3F2EC', 200: '#E6E4DA', 300: '#D3D0C3', 400: '#A5A193', 500: '#7A7668',
  600: '#5D5A4E', 700: '#46443A', 800: '#2F2E26', 900: '#22231B', 950: '#15160F'
};
// Terracota apagado para errores: armoniza con el oliva sin ser un rojo saturado
const terracota = {
  50: '#FBF1EE', 100: '#F6DED7', 200: '#ECBDB0', 300: '#DE9886', 400: '#CC735D',
  500: '#B4533F', 600: '#9A4232', 700: '#7D3528', 800: '#632B21', 900: '#4F241C', 950: '#33170F'
};

module.exports = {
  content: ['./src/**/*.{html,ts}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace']
      },
      colors: {
        brand,
        leaf,
        zinc: neutro,
        stone: neutro,
        sand: { 50: '#FDFCF6', 100: '#FDF8E6', 200: '#F4EFD8', 300: '#E6E0C4' },
        earth: { 50: '#FAF9F4', 100: '#F3F2EC', 300: '#D3D0C3', 400: '#A5A193', 500: '#7A7668', 600: '#5D5A4E', 700: '#46443A' },
        emerald: brand,
        amber: leaf,
        rose: terracota,
        sky: { 50: '#F4F6E4', 100: '#E7ECC9', 200: '#CED89C', 300: '#AFBF68', 400: '#8B9E3F', 500: '#8B9E3F', 600: '#6B7E2B', 700: '#4B5B1D', 800: '#3F4C18', 900: '#333D14' },
        violet: neutro
      },
      boxShadow: {
        soft: '0 1px 2px rgba(38, 46, 15, .05)',
        card: '0 1px 2px rgba(38, 46, 15, .05), 0 1px 3px rgba(38, 46, 15, .04)',
        lifted: '0 6px 20px -6px rgba(38, 46, 15, .16)',
        modal: '0 24px 56px -16px rgba(38, 46, 15, .30)',
        ring: '0 0 0 3px rgba(75, 91, 29, .18)'
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
