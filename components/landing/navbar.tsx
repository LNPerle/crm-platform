export default function Navbar() {
  return (
    <header className="sticky top-0 z-50 border-b border-slate-200 bg-white/80 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
        <div className="text-xl font-bold tracking-tight">
          ✨ Lumeni
        </div>

        <nav className="hidden gap-8 text-sm text-slate-600 md:flex">
          <a href="#features" className="hover:text-slate-900">
            Fonctionnalités
          </a>

          <a href="#why" className="hover:text-slate-900">
            Pourquoi Lumeni
          </a>

          <a href="#" className="hover:text-slate-900">
            Tarifs
          </a>
        </nav>

        <button className="rounded-xl bg-indigo-600 px-5 py-2 text-white hover:bg-indigo-700">
          Connexion
        </button>
      </div>
    </header>
  );
}