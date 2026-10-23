import {useSyncExternalStore} from 'react';

/**
 * Tells listeners when it changes, like Flutter's `ChangeNotifier`.
 *
 * Components listen with {@link useListenable}.
 */
export class ChangeNotifier {
  readonly #listeners = new Set<() => void>();

  /** Grows with every change, so that React can tell that one happened. */
  #version = 0;

  /** Calls `listener` on every change, until the returned function is called. */
  subscribe = (listener: () => void): (() => void) => {
    this.#listeners.add(listener);
    return () => this.#listeners.delete(listener);
  };

  getVersion = (): number => this.#version;

  protected notifyListeners(): void {
    this.#version++;
    for (const listener of this.#listeners) listener();
  }
}

/**
 * Renders the calling component again whenever `notifier` changes, like
 * Flutter's `ListenableBuilder`.
 */
export function useListenable(notifier: ChangeNotifier): void {
  useSyncExternalStore(notifier.subscribe, notifier.getVersion);
}
