import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '@/services/api';
import ResourceState from './ResourceState';

const defaults = {
  error: null,
  loading: false,
  refreshing: false,
  empty: false,
  onRetry: vi.fn(),
  loadingLabel: 'טוען נתונים…',
  emptyLabel: 'אין נתונים.',
};

afterEach(cleanup);

describe('ResourceState', () => {
  it('makes access denial distinct from an empty resource', () => {
    render(<ResourceState {...defaults} error={new ApiError('Forbidden', 403)} />);

    expect(screen.getByText('אין לך הרשאה לצפות בנתונים אלה.')).toBeTruthy();
    expect(screen.queryByText('אין נתונים.')).toBeNull();
  });

  it('offers retry for a recoverable request failure', () => {
    const onRetry = vi.fn();
    render(<ResourceState {...defaults} error={new ApiError('Server unavailable', 503)} onRetry={onRetry} />);

    fireEvent.click(screen.getByRole('button', { name: 'נסה שוב' }));
    expect(onRetry).toHaveBeenCalledOnce();
  });

  it('shows a refresh indicator without replacing existing data', () => {
    render(<ResourceState {...defaults} refreshing />);
    expect(screen.getByText('מעדכן נתונים…')).toBeTruthy();
  });
});
