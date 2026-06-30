export default function Hero() {
  return (
    <section className="flex min-h-screen flex-col items-center justify-center bg-slate-50 px-6 text-center">
      <span className="mb-4 rounded-full bg-indigo-100 px-4 py-1 text-sm font-medium text-indigo-700">
        🚀 Nouveau
      </span>

      <h1 className="max-w-4xl text-5xl font-extrabold tracking-tight text-slate-900 md:text-7xl">
        Fidélisez vos clients.
        <br />
        Développez votre commerce.
      </h1>

      <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">
        Lumeni est la plateforme de fidélité pensée pour les commerces
        indépendants. QR Code, récompenses automatiques, emails et statistiques,
        réunis dans une seule application.
      </p>

      <div className="mt-10 flex flex-wrap justify-center gap-4">
        <button className="rounded-xl bg-indigo-600 px-6 py-3 font-semibold text-white transition hover:bg-indigo-700">
          Commencer
        </button>

        <button className="rounded-xl border border-slate-300 bg-white px-6 py-3 font-semibold text-slate-700 transition hover:bg-slate-100">
          Voir la démo
        </button>
      </div>
    </section>
  );
}