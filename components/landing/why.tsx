export default function Why() {
  return (
    <section
      id="why"
      className="bg-slate-50 py-24"
    >
      <div className="mx-auto max-w-5xl px-6 text-center">

        <h2 className="text-4xl font-bold">
          Pourquoi Lumeni ?
        </h2>

        <p className="mt-6 text-lg text-slate-600">
          Nous avons conçu Lumeni pour les commerces qui veulent
          fidéliser leurs clients sans passer des heures sur des
          tableurs Excel.
        </p>

        <div className="mt-16 grid gap-10 md:grid-cols-3">

          <div>
            <h3 className="text-2xl font-bold">
              ⚡ 5 minutes
            </h3>

            <p className="mt-3 text-slate-600">
              Mise en place ultra rapide.
            </p>
          </div>

          <div>
            <h3 className="text-2xl font-bold">
              ❤️ Plus de fidélité
            </h3>

            <p className="mt-3 text-slate-600">
              Faites revenir davantage de clients.
            </p>
          </div>

          <div>
            <h3 className="text-2xl font-bold">
              📈 Plus de revenus
            </h3>

            <p className="mt-3 text-slate-600">
              Développez votre chiffre d'affaires.
            </p>
          </div>

        </div>
      </div>
    </section>
  );
}