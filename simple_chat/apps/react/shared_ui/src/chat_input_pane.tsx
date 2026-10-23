import {useState, type KeyboardEvent} from 'react';
import {IconButton} from './icon_button';
import './chat_input_pane.css';

/** Where the current answer is: none in progress, being written, or paused. */
export type ChatStatus = 'idle' | 'streaming' | 'paused';

/** What the text field suggests, in each status. */
const hints: Record<ChatStatus, string> = {
  idle: 'Message',
  streaming: 'Add context, or pause',
  paused: 'Add context and resume, just resume, or cancel',
};

interface ChatInputPaneProps {
  status: ChatStatus;

  /** Called with the trimmed text, after which the field is cleared. */
  onSend: (text: string) => void;

  onPause: () => void;
  onResume: () => void;
  onCancel: () => void;

  /** Text in the field when the pane first appears. */
  initialText?: string;
}

/**
 * The text field for the next message, with the buttons that send it and
 * control the current answer.
 *
 * While an answer streams, the user can add context or pause. While it is
 * paused, the user can add context and resume, just resume, or cancel.
 */
export function ChatInputPane({
  status,
  onSend,
  onPause,
  onResume,
  onCancel,
  initialText = '',
}: ChatInputPaneProps) {
  const [text, setText] = useState(initialText);
  const hasText = text.trim() !== '';

  /**
   * Sends the message, or, while paused with nothing typed, resumes.
   *
   * Enter in the text field lands here, so it does what the main button does.
   */
  function send() {
    if (hasText) {
      onSend(text.trim());
      setText('');
    } else if (status === 'paused') {
      onResume();
    }
  }

  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    // Shift+Enter starts a new line, and Enter that ends an input method's
    // composition belongs to the input method.
    if (event.key !== 'Enter' || event.shiftKey) return;
    if (event.nativeEvent.isComposing) return;
    event.preventDefault();
    send();
  }

  return (
    <div className="chat-input-pane">
      <textarea
        className="chat-input-pane__field"
        rows={1}
        value={text}
        placeholder={hints[status]}
        onChange={event => setText(event.target.value)}
        onKeyDown={onKeyDown}
      />
      {status === 'streaming' && (
        <IconButton
          icon="pause"
          tooltip="Pause"
          variant="tonal"
          onClick={onPause}
        />
      )}
      {status === 'paused' && (
        <IconButton
          icon="close"
          tooltip="Cancel"
          variant="tonal"
          onClick={onCancel}
        />
      )}
      {status === 'paused' && !hasText ? (
        <IconButton icon="playArrow" tooltip="Resume" onClick={onResume} />
      ) : (
        <IconButton
          icon="send"
          tooltip={status === 'paused' ? 'Send and resume' : 'Send'}
          onClick={send}
          disabled={!hasText}
        />
      )}
    </div>
  );
}
