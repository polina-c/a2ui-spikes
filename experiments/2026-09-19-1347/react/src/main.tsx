import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
// The package advertises './styles/structural.css' in its export map, but no
// such file ships, and the CSS that does ship (v0_9/index.css) is not exported
// at all. injectStyles() is the path that works.
import {injectStyles} from '@a2ui/react/styles';
import './styles.css';
import App from './App';

injectStyles();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
