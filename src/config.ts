// These values are public client configuration, not privileged credentials.
// Existing Supabase RLS policies continue to protect members' records.
export const appBase = import.meta.env.BASE_URL;
export const supabaseConfig = {
  url: import.meta.env.VITE_SUPABASE_URL || 'https://rslxrwaqvjnxrufarfok.supabase.co',
  key: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_NL3REqDKLR8CNW7lMj75hg_GZ9ZKtyj',
};
export function authRedirect(origin: string) {
  return new URL(appBase, origin).href;
}
