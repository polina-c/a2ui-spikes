import {useState} from 'react';
import {Picker} from './picker';
import {Chat} from './chat';
import type {ModelChoice} from './models';

export function App() {
  const [choice, setChoice] = useState<ModelChoice | null>(null);
  return choice ? (
    <Chat choice={choice} onBack={() => setChoice(null)} />
  ) : (
    <Picker onStart={setChoice} />
  );
}
