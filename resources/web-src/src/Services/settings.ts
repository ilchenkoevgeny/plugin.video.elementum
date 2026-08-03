const refreshRateSettingName = 'refreshRate';
const defaultRefreshRate = 5000;
const themeSettingName = 'theme';

export type Theme = 'dark' | 'light';

export const saveRefreshRate = (refreshRate: number): void => {
  const refreshRateInMs = refreshRate;
  window.localStorage.setItem(refreshRateSettingName, refreshRateInMs.toString());
};

export const getRefreshRate = (): number => {
  const refreshRate = window.localStorage.getItem(refreshRateSettingName);
  return Number(refreshRate ?? defaultRefreshRate);
};

export const saveTheme = (theme: Theme): void => {
  window.localStorage.setItem(themeSettingName, theme);
};

export const getTheme = (): Theme => {
  const theme = window.localStorage.getItem(themeSettingName);
  return theme === 'light' ? 'light' : 'dark';
};

export const applyTheme = (theme: Theme): void => {
  document.documentElement.dataset.theme = theme;
};
