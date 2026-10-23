import {useCallback, useLayoutEffect, useRef, useState} from 'react';
import {IconButton} from './icon_button';
import {Markdown} from './markdown';
import './md_carousel_view.css';

/** Tall enough for a few lines of markdown above the button. */
const carouselHeight = 280;

/** Narrow enough that the next card peeks in and hints at the scrolling. */
const cardWidth = 260;

const cardSpacing = 12;

/**
 * One arrow press moves by a whole card, so cards stay roughly aligned with
 * the edges instead of drifting out of step.
 */
const scrollStep = cardWidth + cardSpacing;

interface MdCarouselViewProps {
  /**
   * The cards to show, in the order of the map: each key is the name shown at
   * the top of a card, each value is the markdown rendered below it.
   *
   * Names double as the identity of a card, so two cards cannot share one.
   */
  items: ReadonlyMap<string, string>;

  /**
   * Called with the name and value of the card whose 'Select' button the user
   * pressed.
   */
  onSelect?: (title: string, value: string) => void;
}

/**
 * A horizontally scrolling list of markdown texts, each with a 'Select'
 * button.
 *
 * Arrow buttons overlay the left and right edges. Each one appears only while
 * there is more to scroll in its direction, so on a list that fits entirely
 * on screen neither is shown.
 */
export function MdCarouselView({items, onSelect}: MdCarouselViewProps) {
  const list = useRef<HTMLDivElement>(null);
  const [canScrollBack, setCanScrollBack] = useState(false);
  const [canScrollForward, setCanScrollForward] = useState(false);

  /** Recomputes which arrows apply. */
  const syncArrows = useCallback(() => {
    const element = list.current;
    if (!element) return;
    const {scrollLeft, clientWidth, scrollWidth} = element;
    setCanScrollBack(scrollLeft > 0);
    // Rounded up, because a zoomed page can stop a fraction of a pixel short
    // of the end.
    setCanScrollForward(Math.ceil(scrollLeft + clientWidth) < scrollWidth);
  }, []);

  // The list can change size without anything scrolling, when the window is
  // resized or the page zoomed, and the cards can change. Both can change
  // which arrows apply.
  useLayoutEffect(() => {
    const element = list.current;
    if (!element) return;
    syncArrows();
    const observer = new ResizeObserver(syncArrows);
    observer.observe(element);
    return () => observer.disconnect();
  }, [items, syncArrows]);

  if (items.size === 0) return null;

  function scrollBy(delta: number) {
    list.current?.scrollBy({left: delta, behavior: 'smooth'});
  }

  return (
    <div className="md-carousel-view" style={{height: carouselHeight}}>
      <div
        ref={list}
        className="md-carousel-view__list"
        style={{gap: cardSpacing}}
        onScroll={syncArrows}
      >
        {[...items].map(([name, markdown]) => (
          <MdCarouselCard
            key={name}
            name={name}
            markdown={markdown}
            onSelect={onSelect && (() => onSelect(name, markdown))}
          />
        ))}
      </div>
      <ScrollArrow
        side="left"
        visible={canScrollBack}
        onClick={() => scrollBy(-scrollStep)}
      />
      <ScrollArrow
        side="right"
        visible={canScrollForward}
        onClick={() => scrollBy(scrollStep)}
      />
    </div>
  );
}

interface ScrollArrowProps {
  side: 'left' | 'right';
  visible: boolean;
  onClick: () => void;
}

/**
 * One of the two arrows overlaying a {@link MdCarouselView}.
 *
 * It fades out rather than disappearing at once. A faded-out arrow is inert,
 * so it takes neither clicks nor focus and cannot scroll an already-ended
 * list.
 */
function ScrollArrow({side, visible, onClick}: ScrollArrowProps) {
  const isLeft = side === 'left';
  return (
    <div
      className={`md-carousel-view__arrow md-carousel-view__arrow--${side}`}
      inert={!visible}
    >
      <IconButton
        icon={isLeft ? 'chevronLeft' : 'chevronRight'}
        tooltip={isLeft ? 'Scroll left' : 'Scroll right'}
        variant="tonal"
        onClick={onClick}
      />
    </div>
  );
}

interface MdCarouselCardProps {
  /** Shown at the top of the card, above the markdown. */
  name: string;

  markdown: string;
  onSelect?: () => void;
}

/** A single card in a {@link MdCarouselView}. */
function MdCarouselCard({name, markdown, onSelect}: MdCarouselCardProps) {
  return (
    <div className="md-carousel-view__card" style={{width: cardWidth}}>
      <div className="md-carousel-view__name">{name}</div>
      {/* The card has a fixed height and the markdown can be any length, so it
          scrolls rather than overflowing. */}
      <div className="md-carousel-view__markdown">
        <Markdown text={markdown} />
      </div>
      {onSelect && (
        <button
          type="button"
          className="md-carousel-view__select"
          onClick={onSelect}
        >
          Select
        </button>
      )}
    </div>
  );
}
