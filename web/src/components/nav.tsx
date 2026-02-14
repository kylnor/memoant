"use client";

import { useState } from "react";

export function Nav() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 glass">
      <div className="max-w-5xl mx-auto flex items-center justify-between h-16 px-6">
        <a href="#" className="text-xl font-bold tracking-tight">
          memoant
        </a>

        {/* Desktop links */}
        <div className="hidden sm:flex items-center gap-8">
          <a
            href="#features"
            className="text-sm text-muted hover:text-foreground transition-colors"
          >
            Features
          </a>
          <a
            href="#how-it-works"
            className="text-sm text-muted hover:text-foreground transition-colors"
          >
            How It Works
          </a>
          <a
            href="#privacy"
            className="text-sm text-muted hover:text-foreground transition-colors"
          >
            Privacy
          </a>
          <a
            href="#install"
            className="text-sm text-muted hover:text-foreground transition-colors"
          >
            Install
          </a>
          <a
            href="https://github.com/kylenorthup/meeting-recorder"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-muted hover:text-foreground transition-colors"
          >
            GitHub
          </a>
        </div>

        {/* Mobile hamburger */}
        <button
          className="sm:hidden text-muted hover:text-foreground"
          onClick={() => setMobileOpen(!mobileOpen)}
          aria-label="Toggle menu"
        >
          <svg
            className="w-6 h-6"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={1.5}
            stroke="currentColor"
          >
            {mobileOpen ? (
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M6 18L18 6M6 6l12 12"
              />
            ) : (
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
              />
            )}
          </svg>
        </button>
      </div>

      {/* Mobile menu */}
      {mobileOpen && (
        <div className="sm:hidden border-t border-border px-6 py-4 space-y-3">
          <a
            href="#features"
            className="block text-sm text-muted hover:text-foreground"
            onClick={() => setMobileOpen(false)}
          >
            Features
          </a>
          <a
            href="#how-it-works"
            className="block text-sm text-muted hover:text-foreground"
            onClick={() => setMobileOpen(false)}
          >
            How It Works
          </a>
          <a
            href="#privacy"
            className="block text-sm text-muted hover:text-foreground"
            onClick={() => setMobileOpen(false)}
          >
            Privacy
          </a>
          <a
            href="#install"
            className="block text-sm text-muted hover:text-foreground"
            onClick={() => setMobileOpen(false)}
          >
            Install
          </a>
          <a
            href="https://github.com/kylenorthup/meeting-recorder"
            target="_blank"
            rel="noopener noreferrer"
            className="block text-sm text-muted hover:text-foreground"
          >
            GitHub
          </a>
        </div>
      )}
    </nav>
  );
}
