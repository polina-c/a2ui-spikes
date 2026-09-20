import {useEffect, useMemo, useRef, useState} from 'react';
import {MessageProcessor} from '@a2ui/web_core/v0_9';
import {A2uiSurface, basicCatalog, MarkdownContext} from '@a2ui/react/v0_9';
import {renderMarkdown} from '@a2ui/markdown-it';
import {corpus, LANDING_URLS, MODEL_IDS} from './knowledge';
import {parseReply, systemPrompt} from './prompt';
import {geminiClient, type Turn} from './gemini';
import {webllmClient} from './local';
import type {ModelChoice} from './models';

/** Step 4 of the CUJ: the first message is already written. */
const OPENING =
  "Hi, I am looking for a dishwasher. I am overwhelmed with choices and don't know where to start.";

interface Entry {
  role: 'user' | 'assistant';
  text: string;
  surfaceId?: string;
  failed?: boolean;
}

export function Chat({choice, onBack}: {choice: ModelChoice; onBack: () => void}) {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [draft, setDraft] = useState(OPENING);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState('');
  const [, redraw] = useState(0);
  const turns = useRef<Turn[]>([]);
  const surfaceCount = useRef(0);
  const bottom = useRef<HTMLDivElement>(null);

  const client = useMemo(
    () =>
      choice.familyId === 'gemini'
        ? geminiClient(choice.modelId)
        : webllmClient(choice.modelId, setStatus),
    [choice],
  );

  // One processor for the whole conversation. Its action handler is what makes
  // the generated UI interactive: a press becomes the next turn.
  const processor = useMemo(
    () =>
      new MessageProcessor([basicCatalog], action => {
        // The web catalog has no link, so the model asks the app to navigate.
        // It names the machine and the app knows the address, because a URL
        // repeated back by a language model is a URL that can lose a segment.
        if (action.name === 'openLandingPage') {
          const url = LANDING_URLS[String(action.context?.model ?? '')];
          if (url) {
            window.open(url, '_blank', 'noopener');
            return;
          }
        }
        void send(
          `The user pressed "${action.sourceComponentId}" in the UI you drew. The action ` +
            `was "${action.name}" with context ${JSON.stringify(action.context ?? {})}. ` +
            `Answer as if they had told you that.`,
          {silent: true},
        );
      }),
    // Built once; `send` is stable enough for this app's lifetime.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  );

  const system = useMemo(() => {
    const caps = processor.getClientCapabilities({includeInlineCatalogs: true}) as any;
    const inline = caps['v0.9']?.inlineCatalogs?.[0] ?? {};
    return systemPrompt(inline, basicCatalog.id, corpus(), MODEL_IDS);
  }, [processor]);

  // A surface arriving is not a React state change, so the chat is told.
  useEffect(() => {
    const bump = () => redraw(n => n + 1);
    const created = processor.onSurfaceCreated(bump);
    const deleted = processor.onSurfaceDeleted(bump);
    return () => {
      created.unsubscribe();
      deleted.unsubscribe();
    };
  }, [processor]);

  useEffect(() => {
    bottom.current?.scrollIntoView({behavior: 'smooth'});
  });

  async function send(text: string, opts?: {silent?: boolean}) {
    if (busy) return;
    setBusy(true);
    if (!opts?.silent) setEntries(e => [...e, {role: 'user', text}]);

    const surfaceId = `turn-${surfaceCount.current++}`;
    turns.current = [
      ...turns.current,
      {role: 'user', text: `${text}\n\n(Draw this answer on surfaceId "${surfaceId}".)`},
    ];

    try {
      const raw = await client.send(system, turns.current, choice);
      turns.current = [...turns.current, {role: 'model', text: raw}];
      const {say, a2ui} = parseReply(raw);

      let drew = false;
      if (a2ui.length > 0) {
        processor.processMessages(a2ui as any);
        drew = processor.model.surfacesMap.has(surfaceId);
      }
      setEntries(e => [
        ...e,
        {
          role: 'assistant',
          text: say || '(no words with this one)',
          surfaceId: drew ? surfaceId : undefined,
        },
      ]);
    } catch (err) {
      setEntries(e => [
        ...e,
        {role: 'assistant', text: `That did not work: ${(err as Error).message}`, failed: true},
      ]);
    } finally {
      setBusy(false);
      setStatus('');
    }
  }

  return (
    <div className="chat">
      <header className="chat-head">
        <div>
          <strong>Just Shining</strong>
          <span className="sub">
            {client.label} &middot; temperature {choice.temperature} &middot; max{' '}
            {choice.maxOutputTokens} tokens
          </span>
        </div>
        <button className="restart" onClick={onBack}>
          Change model
        </button>
      </header>

      <div className="log">
        {entries.length === 0 && (
          <p className="lead">The first message is written for you. Press send when ready.</p>
        )}
        {entries.map((entry, i) => (
          <div key={i} className={`entry ${entry.role}`}>
            <div className={entry.failed ? 'bubble failed' : 'bubble'}>{entry.text}</div>
            {entry.surfaceId && processor.model.surfacesMap.has(entry.surfaceId) && (
              <div className="surface">
                <MarkdownContext.Provider value={renderMarkdown}>
                  <A2uiSurface surface={processor.model.surfacesMap.get(entry.surfaceId)!} />
                </MarkdownContext.Provider>
              </div>
            )}
          </div>
        ))}
        {busy && (
          <div className="entry assistant">
            <div className="bubble pending">{status || 'Thinking...'}</div>
          </div>
        )}
        <div ref={bottom} />
      </div>

      <form
        className="composer"
        onSubmit={e => {
          e.preventDefault();
          const text = draft.trim();
          if (!text) return;
          setDraft('');
          void send(text);
        }}
      >
        <input
          value={draft}
          placeholder="Type a message"
          disabled={busy}
          onChange={e => setDraft(e.target.value)}
        />
        <button type="submit" disabled={busy || !draft.trim()}>
          Send
        </button>
      </form>
    </div>
  );
}
