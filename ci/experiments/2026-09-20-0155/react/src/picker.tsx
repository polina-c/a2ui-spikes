import {useState} from 'react';
import {DEFAULT_CHOICE, ENV_KEY, FAMILIES, type ModelChoice} from './models';

/**
 * Step 2 of the CUJ: the app opens here and offers a default that works.
 *
 * The key box only appears when the environment did not supply one, and it is
 * a password field, so the key is never on screen or in a recording.
 */
export function Picker({onStart}: {onStart: (choice: ModelChoice) => void}) {
  const [familyId, setFamilyId] = useState(DEFAULT_CHOICE.familyId);
  const [modelId, setModelId] = useState(DEFAULT_CHOICE.modelId);
  const [temperature, setTemperature] = useState(DEFAULT_CHOICE.temperature);
  const [maxOutputTokens, setMax] = useState(DEFAULT_CHOICE.maxOutputTokens);
  const [key, setKey] = useState(ENV_KEY);

  const family = FAMILIES.find(f => f.id === familyId)!;
  const ready = !family.needsKey || key.trim().length > 0;

  return (
    <div className="picker">
      <h1>Just Shining</h1>
      <p className="lead">
        Pick the model that answers you. The defaults are the ones we recommend.
      </p>

      <div className="families">
        {FAMILIES.map(f => (
          <button
            key={f.id}
            className={f.id === familyId ? 'family chosen' : 'family'}
            onClick={() => {
              setFamilyId(f.id);
              setModelId(f.models[0].id);
            }}
          >
            <strong>{f.label}</strong>
            <span>{f.note}</span>
          </button>
        ))}
      </div>

      <label>
        Model
        <select value={modelId} onChange={e => setModelId(e.target.value)}>
          {family.models.map(m => (
            <option key={m.id} value={m.id}>
              {m.label}
            </option>
          ))}
        </select>
      </label>

      <div className="row">
        <label>
          Temperature
          <input
            type="number"
            step="0.1"
            min="0"
            max="2"
            value={temperature}
            onChange={e => setTemperature(Number(e.target.value))}
          />
        </label>
        <label>
          Max output tokens
          <input
            type="number"
            step="256"
            min="256"
            value={maxOutputTokens}
            onChange={e => setMax(Number(e.target.value))}
          />
        </label>
      </div>

      {family.needsKey && !ENV_KEY && (
        <label>
          Gemini API key
          <input
            type="password"
            value={key}
            placeholder="Paste your key"
            onChange={e => setKey(e.target.value)}
          />
          <span className="hint">Kept in this tab only, and never sent anywhere but Google.</span>
        </label>
      )}

      <button
        className="start"
        disabled={!ready}
        onClick={() =>
          onStart({
            familyId,
            modelId,
            temperature,
            maxOutputTokens,
            apiKey: family.needsKey ? key.trim() : undefined,
          })
        }
      >
        Start the chat
      </button>
    </div>
  );
}
