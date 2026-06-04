export type ThemeColors = {
  background: string;
  surface: string;
  accent: string;
  accentHover: string;
};

export type Theme = {
  id: string;
  name: string;
  colors: ThemeColors;
};

export const THEMES: Theme[] = [
  {
    id: 'dark-gold',
    name: 'ダークゴールド（デフォルト）',
    colors: { background: '#0a0a0a', surface: '#111111', accent: '#d4a843', accentHover: '#f0c060' },
  },
  {
    id: 'deep-red',
    name: 'ディープレッド',
    colors: { background: '#0d0808', surface: '#160d0d', accent: '#c0392b', accentHover: '#e74c3c' },
  },
  {
    id: 'midnight-blue',
    name: 'ミッドナイトブルー',
    colors: { background: '#080a0d', surface: '#0d1116', accent: '#3498db', accentHover: '#5dade2' },
  },
  {
    id: 'dark-purple',
    name: 'ダークパープル',
    colors: { background: '#0a080d', surface: '#110d16', accent: '#9b59b6', accentHover: '#b97dd1' },
  },
  {
    id: 'forest-green',
    name: 'フォレストグリーン',
    colors: { background: '#080d09', surface: '#0d1610', accent: '#27ae60', accentHover: '#2ecc71' },
  },
  {
    id: 'rose-pink',
    name: 'ローズピンク',
    colors: { background: '#0d0809', surface: '#160d0e', accent: '#e91e8c', accentHover: '#f048a8' },
  },
];

export function getThemeById(id: string): Theme {
  return THEMES.find(t => t.id === id) ?? THEMES[0];
}

export function colorsToCssVars(colors: ThemeColors): string {
  return [
    `--bg-base:${colors.background}`,
    `--bg-surface:${colors.surface}`,
    `--accent:${colors.accent}`,
    `--accent-light:${colors.accentHover}`,
  ].join(';');
}
