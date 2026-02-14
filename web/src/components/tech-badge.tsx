export function TechBadge({ name }: { name: string }) {
  return (
    <div className="glass rounded-lg px-5 py-3 text-sm font-medium text-muted hover:text-foreground transition-colors">
      {name}
    </div>
  );
}
