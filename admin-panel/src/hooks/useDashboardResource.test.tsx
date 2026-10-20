import { act, render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { useDashboardResource } from './useDashboardResource';

function Probe({ load }: { load: () => Promise<string> }) {
  const resource = useDashboardResource(load);
  return <><p>{resource.data ?? 'no data'}</p><p>{resource.refreshing ? 'refreshing' : 'idle'}</p><button type="button" onClick={() => void resource.refresh()}>refresh</button></>;
}

describe('useDashboardResource', () => {
  it('keeps the last successful data visible while refresh is pending', async () => {
    let resolveRefresh: (value: string) => void = () => undefined;
    const load = vi.fn()
      .mockResolvedValueOnce('authoritative data')
      .mockImplementationOnce(() => new Promise<string>((resolve) => { resolveRefresh = resolve; }));
    render(<Probe load={load} />);

    await screen.findByText('authoritative data');
    act(() => screen.getByRole('button', { name: 'refresh' }).click());

    expect(screen.getByText('authoritative data')).toBeTruthy();
    expect(screen.getByText('refreshing')).toBeTruthy();
    await act(async () => { resolveRefresh('new authoritative data'); });
    await waitFor(() => expect(screen.getByText('new authoritative data')).toBeTruthy());
  });
});
