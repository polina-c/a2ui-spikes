import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import {loadGeminiApiKey} from 'shared_ui';
import 'shared_ui/theme.css';
import {ChatPage} from './chat_page';
import {GeminiAssistant} from './gemini';
import {systemPrompt} from './prompt';
import './main.css';

const apiKey = loadGeminiApiKey();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {apiKey === '' ? (
      <p className="missing-key">Set GEMINI_API_KEY to start a chat.</p>
    ) : (
      <ChatPage assistant={new GeminiAssistant(apiKey, systemPrompt)} />
    )}
  </StrictMode>,
);
