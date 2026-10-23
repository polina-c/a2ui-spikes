import {useEffect, useState} from 'react';
import './animated_ellipsis.css';

/** One full cycle of the ellipsis, in milliseconds. */
const period = 1200;

const maxDots = 3;

interface AnimatedEllipsisProps {
  /** The diameter of each dot, in pixels. */
  dotSize?: number;

  /** Defaults to the muted text color of the theme. */
  color?: string;
}

/**
 * Dots that cycle from one to three, showing that more is still coming.
 *
 * Drawn as circles rather than text, because a period is a small glyph even
 * in a large font.
 */
export function AnimatedEllipsis({
  dotSize = 10,
  color = 'var(--color-on-surface-variant)',
}: AnimatedEllipsisProps) {
  const [dots, setDots] = useState(1);

  useEffect(() => {
    const timer = setInterval(
      () => setDots(count => (count % maxDots) + 1),
      period / maxDots,
    );
    return () => clearInterval(timer);
  }, []);

  return (
    <span className="animated-ellipsis" role="status" aria-label="Loading">
      {Array.from({length: maxDots}, (_, i) => (
        // Hidden dots keep their space, so the row does not twitch as the
        // count changes.
        <span
          key={i}
          className="animated-ellipsis__dot"
          style={{
            width: dotSize,
            height: dotSize,
            margin: dotSize / 3,
            background: color,
            opacity: i < dots ? 1 : 0,
          }}
        />
      ))}
    </span>
  );
}
