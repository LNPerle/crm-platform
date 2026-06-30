import {
  QrCode,
  Gift,
  BarChart3,
  Sparkles,
} from "lucide-react";

const features = [
  {
    icon: QrCode,
    title: "QR Code",
    description: "Scannez un client en une seconde.",
  },
  {
    icon: Gift,
    title: "Récompenses",
    description: "Les cadeaux sont envoyés automatiquement.",
  },
  {
    icon: BarChart3,
    title: "Statistiques",
    description: "Suivez vos meilleurs clients.",
  },
  {
    icon: Sparkles,
    title: "IA",
    description: "Recevez des recommandations intelligentes.",
  },
];

export default function Features() {
  return (
    <section
      id="features"
      className="mx-auto max-w-7xl px-6 py-24"
    >
      <h2 className="mb-12 text-center text-4xl font-bold">
        Tout ce qu'il faut pour fidéliser vos clients
      </h2>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        {features.map((feature) => (
          <div
            key={feature.title}
            className="rounded-2xl border border-slate-200 bg-white p-8 shadow-sm transition hover:-translate-y-1 hover:shadow-lg"
          >
            <feature.icon className="mb-4 h-10 w-10 text-indigo-600" />

            <h3 className="mb-2 text-xl font-semibold">
              {feature.title}
            </h3>

            <p className="text-slate-600">
              {feature.description}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}