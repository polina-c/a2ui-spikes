import {useLayoutEffect, useRef, type UIEvent} from 'react';
import {AnimatedEllipsis} from './animated_ellipsis';
import {ChangeNotifier, useListenable} from './change_notifier';
import {Markdown} from './markdown';
import './thinking_box.css';

/**
 * Collects the agent's thinking as it streams in.
 *
 * A {@link ThinkingBox} listens to this, so chunks can be added from wherever
 * the stream is read without holding on to any component.
 */
export class ThinkingBoxController extends ChangeNotifier {
  #isVisible = false;

  /**
   * Whether the box shows at all.
   *
   * Turn this on when a turn starts, before any thought has arrived: the box
   * shows just the ellipsis until the first chunk lands. Turn it off when the
   * turn ends.
   */
  get isVisible(): boolean {
    return this.#isVisible;
  }

  set isVisible(value: boolean) {
    if (this.#isVisible === value) return;
    this.#isVisible = value;
    this.notifyListeners();
  }

  #isPaused = false;

  /**
   * Whether the turn is paused.
   *
   * A paused box stays on screen with its thought, and hides its ellipsis
   * until the turn resumes.
   */
  get isPaused(): boolean {
    return this.#isPaused;
  }

  set isPaused(value: boolean) {
    if (this.#isPaused === value) return;
    this.#isPaused = value;
    this.notifyListeners();
  }

  #thought = '';

  /** Everything added since the last {@link clear}. */
  get text(): string {
    return this.#thought;
  }

  /**
   * Whether no thought has been collected yet.
   *
   * Independent of {@link isVisible}: a visible box with nothing collected
   * shows the ellipsis on its own.
   */
  get isEmpty(): boolean {
    return this.#thought === '';
  }

  /** Appends `mdChunk` to the thought process. */
  addChunk(mdChunk: string): void {
    if (mdChunk === '') return;
    this.#thought += mdChunk;
    this.notifyListeners();
  }

  /**
   * Drops the thought collected so far.
   *
   * Leaves {@link isVisible} alone, so clearing mid-turn falls back to the
   * ellipsis rather than hiding the box.
   */
  clear(): void {
    if (this.#thought === '') return;
    this.#thought = '';
    this.notifyListeners();
  }
}

/**
 * Scroll positions land a fraction of a pixel short of the end often enough
 * that 'at the bottom' has to be a range rather than an exact match.
 */
const tailTolerance = 8;

/**
 * A card that displays the tail of the thought process in Markdown.
 *
 * When {@link ThinkingBoxController.isVisible} is false, nothing is shown.
 * When it is true, shows the tail of the collected thought and an animated
 * ellipsis, or just the ellipsis while no thought has arrived yet.
 */
export function ThinkingBox({controller}: {controller: ThinkingBoxController}) {
  useListenable(controller);
  const thought = controller.text;
  const scroller = useRef<HTMLDivElement>(null);

  /**
   * Whether new thought should pull the view down with it.
   *
   * Scrolling up turns this off, so reading back through the thought is not
   * yanked to the bottom by every chunk that lands. Scrolling back to the
   * bottom turns it on again.
   */
  const followTail = useRef(true);

  // Pins the view to the newest thought, which is what makes the box show the
  // tail rather than the beginning.
  useLayoutEffect(() => {
    // Nothing left to read back through, so the next thought to arrive should
    // pull the view along again.
    if (thought === '') followTail.current = true;
    const element = scroller.current;
    if (element && followTail.current) element.scrollTop = element.scrollHeight;
  });

  // Fires for scrolls, not for content growing, so a chunk landing cannot
  // switch following off by itself.
  function onScroll(event: UIEvent<HTMLDivElement>) {
    const {scrollTop, clientHeight, scrollHeight} = event.currentTarget;
    followTail.current =
      scrollTop + clientHeight >= scrollHeight - tailTolerance;
  }

  if (!controller.isVisible) return null;

  return (
    <div className="thinking-box">
      {/* Nothing collected yet leaves the ellipsis on its own, rather than an
          empty band above it. */}
      {thought !== '' && (
        <div
          ref={scroller}
          className="thinking-box__thought"
          onScroll={onScroll}
        >
          <Markdown text={thought} />
        </div>
      )}
      {/* Kept outside the scroller, so it stays visible while the thought
          above it scrolls. */}
      {!controller.isPaused && (
        <div className="thinking-box__dots">
          <AnimatedEllipsis />
        </div>
      )}
    </div>
  );
}
