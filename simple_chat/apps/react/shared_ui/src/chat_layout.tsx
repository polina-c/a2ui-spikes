import type {ReactNode} from 'react';
import './chat_layout.css';

interface ChatLayoutProps {
  /** What the conversation shows, oldest first. */
  messages: ReactNode;

  /** Shown under the messages, such as a `ChatInputPane`. */
  input: ReactNode;

  /** In pixels. */
  maxWidth?: number;
}

/**
 * The frame of a chat page: the messages, with the input under them.
 *
 * The column is centered and capped in width, so that lines stay readable on a
 * wide window.
 */
export function ChatLayout({messages, input, maxWidth = 800}: ChatLayoutProps) {
  return (
    <div className="chat-layout" style={{maxWidth}}>
      <div className="chat-layout__scroller">
        <div className="chat-layout__messages">{messages}</div>
      </div>
      {input}
    </div>
  );
}
