import { rescueApi, type ApiAlert } from './api';

export async function fetchAlerts(): Promise<{ data: ApiAlert[]; error: string | null }> {
  try {
    return { data: await rescueApi.listAlerts(), error: null };
  } catch (error) {
    return { data: [], error: error instanceof Error ? error.message : 'טעינת ההתראות נכשלה.' };
  }
}
