import {A2uiError, type Parser} from '@a2ui/agent';
import type {ReactCatalogComponent} from '@a2ui/react/v0_9';
import {
  MessageProcessor,
  type ActionListener,
  type Catalog,
  type SurfaceModel,
} from '@a2ui/web_core/v0_9';

/** Text of an answer, in Markdown. */
export class MarkdownPart {
  /** Grows while the answer streams in. */
  text = '';

  /** {@link text} without the blank lines that separate it from the UI. */
  get markdown(): string {
    return this.text.trim();
  }
}

/** UI the model generated for an answer. */
export class SurfacePart {
  readonly surface: SurfaceModel<ReactCatalogComponent>;

  constructor(surface: SurfaceModel<ReactCatalogComponent>) {
    this.surface = surface;
  }
}

/** A piece of an answer, as the user sees it. */
export type AnswerPart = MarkdownPart | SurfacePart;

const openTag = '<a2ui-json>';
const closeTag = '</a2ui-json>';

/** A2UI blocks, including one still open at the end. */
const blocks = new RegExp(`${openTag}[\\s\\S]*?(${closeTag}|$)`, 'g');

/**
 * What an answer shows: its text, and the surfaces its A2UI blocks build, read
 * from the model's output as it streams.
 *
 * Each answer renders its own surfaces, so answers never clash over a surface
 * id.
 */
export class AnswerContent {
  /** Reads the model's output into text and A2UI messages. */
  readonly #parser: Parser;

  /** Turns the A2UI messages into surfaces. */
  readonly #renderer: MessageProcessor<ReactCatalogComponent>;

  readonly #parts: AnswerPart[] = [];

  /** The parts that show something, in the order the model wrote them. */
  get parts(): readonly AnswerPart[] {
    return this.#parts.filter(
      part => !(part instanceof MarkdownPart) || part.markdown !== '',
    );
  }

  /** The model's output so far, as it wrote it. */
  #output = '';

  /**
   * Why the UI stopped rendering, if the model wrote A2UI that does not read
   * or that the renderer rejects.
   */
  #error: A2uiError | null = null;
  get error(): A2uiError | null {
    return this.#error;
  }

  /** Where the output stops being read as A2UI, once there is an error. */
  #failedAt = 0;

  /** The text after {@link #failedAt}, once there is an error. */
  #rest: MarkdownPart | null = null;

  constructor(
    parser: Parser,
    catalog: Catalog<ReactCatalogComponent>,
    onAction: ActionListener,
  ) {
    this.#parser = parser;
    this.#renderer = new MessageProcessor([catalog], onAction);
    this.#renderer.model.onSurfaceCreated.subscribe(surface => {
      this.#parts.push(new SurfacePart(surface));
    });
    this.#renderer.model.onSurfaceDeleted.subscribe(id => {
      const index = this.#parts.findIndex(
        part => part instanceof SurfacePart && part.surface.id === id,
      );
      if (index >= 0) this.#parts.splice(index, 1);
    });
  }

  /** Whether the output so far ends inside an A2UI block. */
  get isInBlock(): boolean {
    return (
      this.#output.lastIndexOf(openTag) > this.#output.lastIndexOf(closeTag)
    );
  }

  /** Reads the next `chunk` of the model's output. */
  add(chunk: string): void {
    let from = this.#output.length;
    this.#output += chunk;
    if (this.#error) return this.#showRest();

    // A read that fails loses the parts it would have returned, so the chunk
    // is read in pieces that end after each open tag. The text before a block
    // then shows even when the block fails in the same chunk.
    const ends: number[] = [];
    let tag = this.#output.indexOf(
      openTag,
      Math.max(0, from - openTag.length + 1),
    );
    while (tag >= 0) {
      ends.push(tag + openTag.length);
      tag = this.#output.indexOf(openTag, tag + 1);
    }
    ends.push(this.#output.length);

    for (const end of ends) {
      const piece = this.#output.slice(from, end);
      if (!this.#read(() => this.#parser.parseChunk(piece), from)) return;
      from = end;
    }
  }

  /**
   * Ends the answer, showing the text held back in case it started a tag.
   *
   * The parser has no way to end a stream, so the answer ends with a line
   * break, which no tag can span.
   */
  close(): void {
    if (this.#error) return;
    this.#read(() => this.#parser.parseChunk('\n'), this.#output.length);
  }

  dispose(): void {
    this.#renderer.dispose();
  }

  /**
   * Shows the parts that `read` returns for the output from `from` on, and
   * whether it succeeded.
   *
   * The parser cannot go on after a failure, so from the block that failed
   * onward, the answer shows its text, with the A2UI left out.
   */
  #read(read: () => ReturnType<Parser['parseChunk']>, from: number): boolean {
    try {
      for (const part of read()) {
        if (part.type === 'text') {
          this.#addText(part.text);
        } else {
          this.#renderer.processMessages(part.a2ui as never);
        }
      }
      return true;
    } catch (error) {
      if (!(error instanceof A2uiError)) throw error;
      this.#error = error;
      const block = this.#output.lastIndexOf(openTag, from);
      this.#failedAt = block >= 0 ? block : from;
      this.#showRest();
      return false;
    }
  }

  #addText(text: string): void {
    let last = this.#parts.at(-1);
    if (!(last instanceof MarkdownPart)) {
      last = new MarkdownPart();
      this.#parts.push(last);
    }
    last.text += text;
  }

  /** Shows the text from where the output stopped being read as A2UI. */
  #showRest(): void {
    const rest = this.#output.slice(this.#failedAt).replace(blocks, '');
    if (rest.trim() === '') return;
    if (!this.#rest) {
      this.#rest = new MarkdownPart();
      this.#parts.push(this.#rest);
    }
    this.#rest.text = rest;
  }
}
