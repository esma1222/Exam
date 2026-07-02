// Supabase connection settings for the OAC exam app.
//
// The publishable key is designed to be shipped in client-side code: it can
// only do what the table Row Level Security (RLS) policies allow — here, read
// the public question bank and insert exam attempts. It is NOT the secret
// service_role key, which must never appear in the frontend.
export const SUPABASE_URL = 'https://mtirftmfjdcdjwhdckhz.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_5CZDf1Ga0mLs8IbTOIK_pw_pxm4xDTS';
