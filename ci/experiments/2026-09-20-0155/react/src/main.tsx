import React from 'react';
import {createRoot} from 'react-dom/client';
import {injectStyles} from '@a2ui/react/styles';
import {App} from './app';
import './styles.css';

// The package advertises ./styles/structural.css in its export map without
// shipping it, and does not export the v0_9/index.css it does ship, so the
// only way in is this call.
injectStyles();

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
