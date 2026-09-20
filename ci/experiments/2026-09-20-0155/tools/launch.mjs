/**
 * How to start the browser.
 *
 * The container ships one Chromium under PLAYWRIGHT_BROWSERS_PATH and forbids
 * downloading another, so a Playwright newer than that build looks for a
 * revision that is not there. Naming the binary directly sidesteps the version
 * check, and `channel: 'chromium'` keeps the full browser rather than the
 * headless shell, which is the build that can record video.
 */
import fs from 'node:fs';

const PINNED = '/opt/pw-browsers/chromium';

export const LAUNCH = fs.existsSync(PINNED)
  ? {executablePath: fs.realpathSync(PINNED)}
  : {};
