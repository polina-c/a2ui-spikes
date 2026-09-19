import {useEffect, useMemo, useRef, useState} from 'react';
import {MessageProcessor} from '@a2ui/web_core/v0_9';
import {A2uiSurface, basicCatalog, MarkdownContext} from '@a2ui/react/v0_9';
import {renderMarkdown} from '@a2ui/markdown-it';
import {buildSystemPrompt} from '../prompt';
import {domainCorpus} from '../domain';
import {geminiClient} from '../llm/gemini';
import {webllmClient} from '../llm/webllm';
import type {Turn} from '../llm/types';
import type {ModelChoice} from '../models';

const DEFAULT_PROMPT =
  "Hi, I am looking for a dishwasher. I am overwhelmed with choices and don't know where to start.";

interface Entry {
  role: 'user' | 'assistant';
  text: string;
  surfaceId?: string;
  failed?: boolean;
}

/** Pulls the JSON object out of a reply, tolerating a stray markdown fence. */
function parseReply(raw: string): {say: string; a2ui: unknown[]} {
  let text = raw.trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```(?:json)?\s*/, '').replace(/```\s*$/, '');
  }
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1) throw new Error('The reply had no JSON object in it.');

  const parsed = JSON.parse(text.slice(start, end + 1));
  return {
    say: typeof parsed.say === 'string' ? parsed.say : '',
    a2ui: Array.isArray(parsed.a2ui) ? parsed.a2ui : [],
  };
}

export function Chat({choice, onRestart}: {choice: ModelChoice; onRestart: () => void}) {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [draft, setDraft] = useState(DEFAULT_PROMPT);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState('');
  const [tick, setTick] = useState(0);
  const turns = useRef<Turn[]>([]);
  const nextSurface = useRef(0);
  const bottom = useRef<HTMLDivElement>(null);

  // The processor is built once. Its action handler feeds clicks back into the
  // conversation, which is what makes the generated UI interactive rather than
  // a picture.
  const processor = useMemo(() => {
    const p = new MessageProcessor([basicCatalog], action => {
      // The catalog cannot express a hyperlink, so opening one is the host
      // app's job: the model asks for it by name and the app does it.
      const url = action.context?.url;
      if (action.name === 'openLandingPage' && typeof url === 'string') {
        window.open(url, '_blank', 'noopener');
        return;
      }
      const context = JSON.stringify(action.context ?? {});
      void send(
        `The user pressed "${action.sourceComponentId}" in the UI you drew. ` +
          `The action was "${action.name}" with context ${context}. ` +
          `Answer as if they had told you this.`,
        {hidden: true},
      );
    });
    return p;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const client = useMemo(
    () =>
      choice.familyId === 'gemini'
        ? geminiClient(choice.modelId)
        : webllmClient(choice.modelId, setStatus),
    [choice],
  );

  const system = useMemo(() => {
    const caps = processor.getClientCapabilities({includeInlineCatalogs: true}) as any;
    const inline = caps['v0.9']?.inlineCatalogs?.[0] ?? {};
    return buildSystemPrompt(inline, basicCatalog.id, domainCorpus());
  }, [processor]);

  useEffect(() => {
    const sync = () => setTick(t => t + 1);
    const created = processor.onSurfaceCreated(sync);
    const deleted = processor.onSurfaceDeleted(sync);
    return () => {
      created.unsubscribe();
      deleted.unsubscribe();
    };
  }, [processor]);

  useEffect(() => {
    bottom.current?.scrollIntoView({behavior: 'smooth'});
  }, [entries, tick]);

  async function send(text: string, opts?: {hidden?: boolean}) {
    if (busy) return;
    setBusy(true);
    setStatus('');

    if (!opts?.hidden) setEntries(e => [...e, {role: 'user', text}]);

    const surfaceId = `turn-${nextSurface.current++}`;
    turns.current = [
      ...turns.current,
      {role: 'user', text: `${text}\n\n(Draw your answer on surfaceId "${surfaceId}".)`},
    ];

    try {
      const raw = await client.send(system, turns.current, choice);
      const {say, a2ui} = parseReply(raw);

      turns.current = [...turns.current, {role: 'model', text: raw}];

      let drew = false;
      if (a2ui.length > 0) {
        processor.processMessages(a2ui as any);
        drew = processor.model.surfacesMap.has(surfaceId);
      }

      setEntries(e => [
        ...e,
        {role: 'assistant', text: say || '(no words with this one)', surfaceId: drew ? surfaceId : undefined},
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
            {client.label} - temperature {choice.temperature}, max {choice.maxOutputTokens} tokens
          </span>
        </div>
        <button className="restart" onClick={onRestart}>
          Change model
        </button>
      </header>

      <div className="log">
        {entries.length === 0 && (
          <p className="lead">
            The first message is already written for you. Press send when you are ready.
          </p>
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
          onChange={e => setDraft(e.target.value)}
          disabled={busy}
        />
        <button type="submit" disabled={busy || !draft.trim()}>
          Send
        </button>
      </form>
    </div>
  );
}
