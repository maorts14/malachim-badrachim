import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import type { ApiAlert, ApiGroup, ApiMessage } from './api';

type ContractCorpus = { alert: ApiAlert; group: ApiGroup; message: ApiMessage };

const contract = JSON.parse(
  readFileSync(resolve(process.cwd(), '../contracts/alert-group-message.json'), 'utf8'),
) as ContractCorpus;

describe('shared API contract corpus', () => {
  it('keeps the admin Alert, Group, and Message DTOs aligned with the checked-in examples', () => {
    const { alert, group, message } = contract;

    expect(alert.status).toBe('DISPATCHED');
    expect(alert.assignments[0].responded_at).toBeNull();
    expect(group.members).toEqual([7, 8]);
    expect(message.alert).toBe(42);
    expect(message.group).toBeNull();
    expect(message.latitude).toBeNull();
  });
});
