import type { ReactNode } from "react";

export function FeatureCard({
  icon,
  title,
  description,
  color,
}: {
  icon: ReactNode;
  title: string;
  description: string;
  color: "coral" | "teal";
}) {
  const colorClasses =
    color === "coral"
      ? "bg-coral/10 text-coral"
      : "bg-teal/10 text-teal";

  const hoverClass =
    color === "coral" ? "glow-coral" : "glow-teal";

  return (
    <div
      className={`glass rounded-xl p-6 transition-all hover:-translate-y-1 ${hoverClass}`}
    >
      <div
        className={`inline-flex items-center justify-center w-10 h-10 rounded-lg ${colorClasses} mb-4`}
      >
        {icon}
      </div>
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-sm text-muted leading-relaxed">{description}</p>
    </div>
  );
}
