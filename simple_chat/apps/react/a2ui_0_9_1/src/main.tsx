import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import {loadGeminiApiKey} from 'shared_ui';
import 'shared_ui/theme.css';
import {ChatPage} from './chat_page';
import {GeminiAssistant} from './gemini';
import {GeneratedUi} from './generated_ui';
import {systemPrompt} from './prompt';
import './a2ui_theme.css';
import './main.css';

const apiKey = loadGeminiApiKey();
const ui = new GeneratedUi();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {apiKey === '' ? (
      <p className="missing-key">Set GEMINI_API_KEY to start a chat.</p>
    ) : (
      <ChatPage
        assistant={new GeminiAssistant(apiKey, systemPrompt(ui.prompt))}
        ui={ui}
      />
    )}
  </StrictMode>,
);
