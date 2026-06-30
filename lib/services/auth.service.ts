"use client";

import { createClient } from "../supabase/client";

export async function signInWithMagicLink(email: string) {
  const supabase = createClient();

  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: "http://localhost:3000/auth/callback",
    },
  });

  if (error) {
    throw error;
  }
}