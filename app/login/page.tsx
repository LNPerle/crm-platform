"use client";

import { useState } from "react";
import { signInWithMagicLink } from "@/lib/services/auth.service";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  async function handleLogin() {
    try {
      setLoading(true);

      await signInWithMagicLink(email);

      setMessage("📩 Vérifie ta boîte mail.");
    } catch (error) {
      console.error(error);
      alert("Une erreur est survenue.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-xl">

        <h1 className="mb-2 text-3xl font-bold">
          Connexion
        </h1>

        <p className="mb-6 text-slate-600">
          Entrez votre email pour recevoir un lien de connexion.
        </p>

        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="vous@email.com"
          className="mb-4 w-full rounded-xl border p-3"
        />

        <button
          onClick={handleLogin}
          disabled={loading}
          className="w-full rounded-xl bg-indigo-600 py-3 text-white transition hover:bg-indigo-700 disabled:opacity-50"
        >
          {loading ? "Envoi..." : "Recevoir un lien magique"}
        </button>

        {message && (
          <p className="mt-4 text-center text-green-600">
            {message}
          </p>
        )}
      </div>
    </main>
  );
}