export default function Footer() {
  return (
    <footer className="border-t border-slate-200 py-10">
      <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 px-6 text-sm text-slate-500 md:flex-row">
        <span>© 2026 Lumeni</span>

        <div className="flex gap-6">
          <a href="#">Confidentialité</a>
          <a href="#">Mentions légales</a>
        </div>
      </div>
    </footer>
  );
}