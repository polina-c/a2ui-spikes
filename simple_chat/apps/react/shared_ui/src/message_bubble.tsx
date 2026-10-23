import {Markdown} from './markdown';
import './message_bubble.css';

interface MessageBubbleProps {
  text: string;

  /** Whether the user wrote this message, rather than the model. */
  isUser: boolean;

  /** Whether the user paused this answer before it was finished. */
  interrupted?: boolean;

  /** Whether this interrupted answer can still be resumed. */
  isPaused?: boolean;
}

/**
 * One message of a chat, in a rounded bubble.
 *
 * A message from the user sits on the right and shows its text as typed. A
 * message from the model sits on the left and renders its text as Markdown,
 * with links and images. An answer the user interrupted is marked 'Paused'
 * while it can still be resumed, and 'Stopped' after that.
 */
export function MessageBubble({
  text,
  isUser,
  interrupted = false,
  isPaused = false,
}: MessageBubbleProps) {
  return (
    <div
      className={`message-bubble message-bubble--${isUser ? 'user' : 'model'}`}
    >
      {isUser ? (
        <div className="message-bubble__text">{text}</div>
      ) : (
        <Markdown text={text} />
      )}
      {interrupted && (
        <div className="message-bubble__status">
          {isPaused ? 'Paused' : 'Stopped'}
        </div>
      )}
    </div>
  );
}
