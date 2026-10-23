import '@testing-library/jest-dom/vitest';
import {cleanup} from '@testing-library/react';
import {afterEach} from 'vitest';

// Testing Library unmounts on its own only when test functions are global.
afterEach(cleanup);
