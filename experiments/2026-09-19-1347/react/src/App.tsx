import {useState} from 'react';
import {ModelPicker} from './components/ModelPicker';
import {Chat} from './components/Chat';
import type {ModelChoice} from './models';

export default function App() {
  const [choice, setChoice] = useState<ModelChoice | null>(null);

  // Remounting the chat on a new choice throws away the old processor and the
  // old conversation, which is what changing the model should do.
  return choice ? (
    <Chat key={choice.modelId} choice={choice} onRestart={() => setChoice(null)} />
  ) : (
    <ModelPicker onStart={setChoice} />
  );
}
