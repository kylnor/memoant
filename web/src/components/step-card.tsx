import type { ReactNode } from "react";

export function StepCard({
  step,
  title,
  description,
  icon,
}: {
  step: number;
  title: string;
  description: string;
  icon: ReactNode;
}) {
  return (
    <div className="text-center">
      <div className="relative inline-flex items-center justify-center w-16 h-16 rounded-2xl glass text-coral mb-6">
        {icon}
        <span className="absolute -top-2 -right-2 flex items-center justify-center w-6 h-6 rounded-full bg-coral text-white text-xs font-bold">
          {step}
        </span>
      </div>
      <h3 className="text-xl font-semibold mb-3">{title}</h3>
      <p className="text-muted text-sm leading-relaxed">{description}</p>
    </div>
  );
}
