import {Fragment, useEffect, useState} from 'react';
import {
  AnimatedEllipsis,
  ChatInputPane,
  ChatLayout,
  MessageBubble,
  ThinkingBox,
  useListenable,
} from 'shared_ui';
import {ChatController, type Assistant} from './chat_controller';
import './chat_page.css';

export const firstPrompt =
  "Hi, I am looking for a dishwasher. I am overwhelmed with choices and don't know where to start.";

export function ChatPage({assistant}: {assistant: Assistant}) {
  const [chat] = useState(() => new ChatController(assistant));
  useEffect(() => () => chat.dispose(), [chat]);
  useListenable(chat);

  const {status, currentAnswer: current, error} = chat;

  const messages = chat.messages.map(message => {
    const isCurrent = message === current;
    return (
      <Fragment key={message.id}>
        {message.text !== '' && (
          <MessageBubble
            text={message.text}
            isUser={message.role === 'user'}
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
  );
}
