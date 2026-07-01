export default function OnboardingPage() {
  return (
    <main className="min-h-screen bg-slate-50 flex items-center justify-center px-6">
      <div className="w-full max-w-xl rounded-3xl bg-white p-10 shadow-xl">

        <h1 className="text-4xl font-bold text-slate-900">
          Bienvenue 👋
        </h1>

        <p className="mt-3 text-slate-600">
          Commençons par créer votre commerce.
        </p>

        <form className="mt-10 space-y-6">

          <div>
            <label className="block text-sm font-medium mb-2">
              Nom du commerce
            </label>

            <input
              type="text"
              placeholder="Ex : Escale à Saigon"
              className="w-full rounded-xl border border-slate-300 px-4 py-3 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2">
              Secteur d'activité
            </label>

            <select
              className="w-full rounded-xl border border-slate-300 px-4 py-3"
            >
              <option>Restaurant</option>
              <option>Boulangerie</option>
              <option>Pâtisserie</option>
              <option>Salon de coiffure</option>
              <option>Institut de beauté</option>
              <option>Bar</option>
              <option>Café</option>
              <option>Autre</option>
            </select>
          </div>

          <button
            className="w-full rounded-xl bg-indigo-600 py-3 font-semibold text-white transition hover:bg-indigo-700"
          >
            Continuer →
          </button>

        </form>

      </div>
    </main>
  );
}