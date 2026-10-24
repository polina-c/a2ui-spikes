import {A2uiSurface, MarkdownContext} from '@a2ui/react';
import type {MarkdownRenderer} from '@a2ui/web_core';
import {Fragment, useEffect, useState} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {
  AnimatedEllipsis,
  ChatInputPane,
  ChatLayout,
  Markdown,
  MessageBubble,
  ThinkingBox,
  useListenable,
} from 'shared_ui';
import {MarkdownPart, SurfacePart} from './answer_content';
import {
  ChatController,
  type Assistant,
  type ChatMessage,
} from './chat_controller';
import type {GeneratedUi} from './generated_ui';
import './chat_page.css';

export const firstPrompt =
  "Hi, I am looking for a dishwasher. I am overwhelmed with choices and don't know where to start.";

/**
 * Renders the Markdown that models often write in a `Text` component the way
 * the messages render it.
 */
const renderMarkdown: MarkdownRenderer = async markdown =>
  renderToStaticMarkup(<Markdown text={markdown} />);

interface ChatPageProps {
  assistant: Assistant;
  ui: GeneratedUi;
}

export function ChatPage({assistant, ui}: ChatPageProps) {
  const [chat] = useState(() => new ChatController(assistant, ui));
  useEffect(() => () => chat.dispose(), [chat]);
  useListenable(chat);

  const {status, currentAnswer: current, error} = chat;

  const messages = chat.messages.map(message => {
    const isCurrent = message === current;
    return (
      <Fragment key={message.id}>
        {message.role === 'user' ? (
          <MessageBubble text={message.text} isUser />
        ) : (
          <Answer
            chat={chat}
            answer={message}
            // A resumed answer is being written again, so it is marked only
            // while paused.
            interrupted={
              message.interrupted && !(isCurrent && status === 'streaming')
            }
            // Only the current answer can still be resumed; an earlier one
            // was stopped for good.
            isPaused={isCurrent && status === 'paused'}
          />
        )}
        {/* Kept with the current answer, above any context the user sends
            meanwhile. */}
        {isCurrent && <ThinkingBox controller={chat.thinking} />}
        {/* Once the answer is streaming the thinking box is gone, so the dots
            carry on under the answer instead. */}
        {isCurrent && status === 'streaming' && !chat.thinking.isVisible && (
          <div className="chat-page__dots">
            <AnimatedEllipsis />
          </div>
        )}
      </Fragment>
    );
  });

  return (
    <MarkdownContext value={renderMarkdown}>
      <ChatLayout
        messages={
          <>
            {messages}
            {error !== null && (
              <p className="chat-page__error">
                {`Could not get an answer: ${error}\n` +
                  'Resume to try again, or cancel.'}
              </p>
            )}
          </>
        }
        input={
          <ChatInputPane
            status={status}
            initialText={firstPrompt}
            onSend={text => chat.send(text)}
            onPause={() => chat.pause()}
            onResume={() => chat.resume()}
            onCancel={() => chat.cancel()}
          />
        }
      />
    </MarkdownContext>
  );
}

interface AnswerProps {
  chat: ChatController;
  answer: ChatMessage;

  /** Whether the user paused this answer before it was finished. */
  interrupted: boolean;

  /** Whether this interrupted answer can still be resumed. */
  isPaused: boolean;
}

/**
 * The text and the UI of `answer`, in the order the model wrote them.
 *
 * An interrupted answer is marked on its last bubble, so when it ends in UI,
 * an empty bubble follows to carry the mark.
 */
function Answer({chat, answer, interrupted, isPaused}: AnswerProps) {
  const content = chat.contentOf(answer);
  const {parts, error} = content;
  const last = parts.at(-1);
  return (
    <>
      {parts.map((part, i) =>
        part instanceof MarkdownPart ? (
          <MessageBubble
            key={i}
            text={part.markdown}
            isUser={false}
            interrupted={interrupted && part === last}
            isPaused={isPaused}
          />
        ) : (
          <AnswerSurface key={part.surface.id} part={part} />
        ),
      )}
      {interrupted && answer.text !== '' && !(last instanceof MarkdownPart) && (
        <MessageBubble text="" isUser={false} interrupted isPaused={isPaused} />
      )}
      {error !== null && (
        <p className="chat-page__error">
          {`Could not show all of the UI: ${error.message}`}
        </p>
      )}
    </>
  );
}

/** UI the model generated for an answer. */
function AnswerSurface({part}: {part: SurfacePart}) {
  return (
    <div className="chat-page__surface">
      <A2uiSurface surface={part.surface} />
    </div>
  );
}
