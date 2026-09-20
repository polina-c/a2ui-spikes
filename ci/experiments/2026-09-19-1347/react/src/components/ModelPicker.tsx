import {useState} from 'react';
import {FAMILIES, DEFAULT_FAMILY, DEFAULT_MODEL, type ModelChoice} from '../models';

/** The key baked in at build time, if there was one in the environment. */
const ENV_KEY: string = import.meta.env.VITE_GEMINI_API_KEY ?? '';

export function ModelPicker({onStart}: {onStart: (choice: ModelChoice) => void}) {
  const [familyId, setFamilyId] = useState(DEFAULT_FAMILY.id);
  const [modelId, setModelId] = useState(DEFAULT_MODEL.id);
  const [apiKey, setApiKey] = useState(ENV_KEY);
  const [params, setParams] = useState<Record<string, number>>(() =>
    Object.fromEntries(DEFAULT_MODEL.params.map(p => [p.key, p.value])),
  );

  const family = FAMILIES.find(f => f.id === familyId)!;
  const model = family.models.find(m => m.id === modelId) ?? family.models[0];
  const needsKey = familyId === 'gemini' && !ENV_KEY;
  const ready = !needsKey || apiKey.trim().length > 0;

  function pickModel(id: string) {
    setModelId(id);
    const next = family.models.find(m => m.id === id)!;
    setParams(Object.fromEntries(next.params.map(p => [p.key, p.value])));
  }

  function pickFamily(id: 'gemini' | 'local') {
    setFamilyId(id);
    const next = FAMILIES.find(f => f.id === id)!;
    setModelId(next.models[0].id);
    setParams(Object.fromEntries(next.models[0].params.map(p => [p.key, p.value])));
  }

  return (
    <div className="panel">
      <h1>Just Shining</h1>
      <p className="lead">
        Pick the model that will answer you. The defaults are already chosen, so you
        can go straight to the chat.
      </p>

      <h2>Model family</h2>
      <div className="row">
        {FAMILIES.map(f => (
          <button
            key={f.id}
            className={f.id === familyId ? 'choice on' : 'choice'}
            onClick={() => pickFamily(f.id)}
          >
            <strong>{f.label}</strong>
            <span>{f.note}</span>
          </button>
        ))}
      </div>

      <h2>Model</h2>
      <div className="col">
        {family.models.map(m => (
          <button
            key={m.id}
            className={m.id === model.id ? 'choice wide on' : 'choice wide'}
            onClick={() => pickModel(m.id)}
          >
            <strong>
              {m.label}
              {m.id === DEFAULT_MODEL.id && family.id === DEFAULT_FAMILY.id ? ' (default)' : ''}
            </strong>
            <span>{m.note}</span>
          </button>
        ))}
      </div>

      <h2>Parameters</h2>
      {model.params.map(p => (
        <label key={p.key} className="param">
          <span className="param-name">{p.label}</span>
          <input
            type="range"
            min={p.min}
            max={p.max}
            step={p.step}
            value={params[p.key] ?? p.value}
            onChange={e => setParams({...params, [p.key]: Number(e.target.value)})}
          />
          <span className="param-value">{params[p.key] ?? p.value}</span>
          <span className="param-range">
            allowed {p.min} to {p.max}
          </span>
        </label>
      ))}

      {needsKey && (
        <>
          <h2>Gemini API key</h2>
          <p className="lead">
            No key was found in the environment, so the app needs one to talk to Gemini.
            It stays in this browser tab.
          </p>
          <input
            className="key"
            type="password"
            placeholder="Paste your API key"
            value={apiKey}
            onChange={e => setApiKey(e.target.value)}
          />
        </>
      )}
      {familyId === 'gemini' && ENV_KEY && (
        <p className="lead">A key was found in the environment, so none is needed here.</p>
      )}

      <button
        className="go"
        disabled={!ready}
        onClick={() =>
          onStart({
            familyId,
            modelId: model.id,
            temperature: params.temperature ?? 0.7,
            maxOutputTokens: params.maxOutputTokens ?? 2048,
            apiKey: familyId === 'gemini' ? apiKey || ENV_KEY : undefined,
          })
        }
      >
        Start the chat
      </button>
    </div>
  );
}
