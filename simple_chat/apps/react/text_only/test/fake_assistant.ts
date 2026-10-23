import type {AnswerChunk, Assistant, ChatMessage} from '../src/chat_controller';

/** An assistant whose answers the test writes chunk by chunk. */
export class FakeAssistant implements Assistant {
  /** The history passed with each request, oldest request first. */
  readonly requests: (readonly ChatMessage[])[] = [];

  /** Whether the current answer has been cancelled, such as by a pause. */
  cancelled = false;

  #answer!: ReadableStreamDefaultController<AnswerChunk>;

  answer(
    history: readonly ChatMessage[],
    signal: AbortSignal,
  ): AsyncIterable<AnswerChunk> {
    this.requests.push(history);
    this.cancelled = false;
    const answer = new ReadableStream<AnswerChunk>({
      start: controller => (this.#answer = controller),
    });
    const controller = this.#answer;
    signal.addEventListener('abort', () => {
      this.cancelled = true;
      controller.error(signal.reason);
    });
    return answer;
  }

  think(text: string): void {
    this.#answer.enqueue({text, isThought: true});
  }

  write(text: string): void {
    this.#answer.enqueue({text, isThought: false});
  }

  fail(error: Error): void {
    this.#answer.error(error);
  }

  finish(): void {
    this.#answer.close();
  }
}

/** Lets the answer catch up with what the test wrote. */
export const flush = () => new Promise(resolve => setTimeout(resolve, 0));
