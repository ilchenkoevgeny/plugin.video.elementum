import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import { applyTheme, getTheme } from './Services/settings';

applyTheme(getTheme());

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root'),
);
