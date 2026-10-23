import './icon_button.css';

/** Paths of the Material icons the components use, so no icon font loads. */
const iconPaths = {
  send: 'M2.01 21L23 12 2.01 3 2 10l15 2-15 2z',
  pause: 'M6 19h4V5H6v14zm8-14v14h4V5h-4z',
  close:
    'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
  playArrow: 'M8 5v14l11-7z',
  chevronLeft: 'M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z',
  chevronRight: 'M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z',
};

interface IconButtonProps {
  icon: keyof typeof iconPaths;

  /** Shown on hover, and read out by screen readers as the button's name. */
  tooltip: string;

  /** Filled for the main action, tonal for the others. */
  variant?: 'filled' | 'tonal';

  onClick: () => void;
  disabled?: boolean;
}

/** A round button with an icon, like Flutter's `IconButton.filled`. */
export function IconButton({
  icon,
  tooltip,
  variant = 'filled',
  onClick,
  disabled = false,
}: IconButtonProps) {
  return (
    <button
      type="button"
      className={`icon-button icon-button--${variant}`}
      title={tooltip}
      aria-label={tooltip}
      onClick={onClick}
      disabled={disabled}
    >
      <svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true">
        <path d={iconPaths[icon]} fill="currentColor" />
      </svg>
    </button>
  );
}
