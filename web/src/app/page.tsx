import { TerminalDemo } from "@/components/terminal-demo";
import { FeatureCard } from "@/components/feature-card";
import { StepCard } from "@/components/step-card";
import { TechBadge } from "@/components/tech-badge";
import { Nav } from "@/components/nav";

export default function Home() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Nav />

      {/* Hero */}
      <section className="relative overflow-hidden gradient-radial pt-32 pb-20 px-6">
        <div className="max-w-5xl mx-auto text-center">
          <div className="inline-flex items-center gap-2 px-3 py-1 mb-8 text-sm rounded-full glass text-muted opacity-0 animate-fade-in-up">
            <span className="w-2 h-2 bg-coral rounded-full" />
            Open source &middot; Runs on your Mac &middot; macOS native
          </div>

          <h1 className="text-5xl sm:text-7xl font-bold tracking-tight mb-6 opacity-0 animate-fade-in-up animate-delay-100">
            Your meetings,{" "}
            <span className="bg-gradient-to-r from-coral to-[#f4a261] bg-clip-text text-transparent">
              remembered.
            </span>
          </h1>

          <p className="text-lg sm:text-xl text-muted max-w-2xl mx-auto mb-10 opacity-0 animate-fade-in-up animate-delay-200">
            One-click recording. Automatic transcription with speaker
            identification. AI-powered metadata extraction. Everything organized
            into Obsidian notes. All processing happens on your Mac.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-16 opacity-0 animate-fade-in-up animate-delay-300">
            <a
              href="#install"
              className="inline-flex items-center justify-center h-12 px-8 rounded-lg bg-coral text-white font-medium transition-all hover:bg-coral-dark glow-coral"
            >
              Get Started
            </a>
            <a
              href="https://github.com/kylnor/memoant"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center h-12 px-8 rounded-lg border border-border text-foreground font-medium transition-all hover:bg-surface hover:border-muted"
            >
              <svg
                className="w-5 h-5 mr-2"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
              </svg>
              View on GitHub
            </a>
          </div>

          <div className="opacity-0 animate-fade-in-up animate-delay-400">
            <TerminalDemo />
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="py-24 px-6">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              Everything you need. Nothing you don&apos;t.
            </h2>
            <p className="text-muted text-lg max-w-xl mx-auto">
              Record, transcribe, and organize meetings with zero configuration
              with on-device AI processing.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <FeatureCard
              icon={
                <svg
                  className="w-6 h-6"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z"
                  />
                </svg>
              }
              title="One-Click Recording"
              description="Launch from Raycast with a keystroke. Record audio-only or capture a specific window with the native macOS picker."
              color="coral"
            />
            <FeatureCard
              icon={
                <svg
                  className="w-6 h-6"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
                  />
                </svg>
              }
              title="Auto Transcription"
              description="WhisperX delivers accurate transcription with timestamps. Works entirely on-device using your GPU or CPU."
              color="coral"
            />
            <FeatureCard
              icon={
                <svg
                  className="w-6 h-6"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"
                  />
                </svg>
              }
              title="Speaker Identification"
              description="Pyannote diarization labels who said what. Your transcript shows Speaker 1, Speaker 2, and so on."
              color="coral"
            />
            <FeatureCard
              icon={
                <svg
                  className="w-6 h-6"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z"
                  />
                </svg>
              }
              title="AI Metadata"
              description="Ollama extracts summaries, action items, decisions, key points, and tags. Structured data, not just a wall of text."
              color="teal"
            />
            <FeatureCard
              icon={
                <svg
                  className="w-6 h-6"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"
                  />
                </svg>
              }
              title="Obsidian Integration"
              description="Every meeting becomes a richly-formatted Obsidian note with frontmatter, transcript, and AI insights ready to link."
              color="teal"
            />
            <FeatureCard
              icon={
                <svg
                  className="w-6 h-6"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
                  />
                </svg>
              }
              title="Privacy First"
              description="No accounts. No telemetry. All AI processing on your Mac. Audio never leaves your machine."
              color="teal"
            />
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section id="how-it-works" className="py-24 px-6 gradient-radial-teal">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              Three steps. Zero friction.
            </h2>
            <p className="text-muted text-lg max-w-xl mx-auto">
              Hit a keystroke, have a conversation, come back to organized notes.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <StepCard
              step={1}
              title="Record"
              description="Open Raycast. Type 'record'. Pick audio or screen mode. That's it. Recording starts instantly."
              icon={
                <svg
                  className="w-8 h-8"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <circle cx="12" cy="12" r="9" />
                  <circle cx="12" cy="12" r="4" fill="currentColor" />
                </svg>
              }
            />
            <StepCard
              step={2}
              title="Process"
              description="Stop the recording and Memoant takes over. WhisperX transcribes, pyannote identifies speakers, Ollama extracts metadata."
              icon={
                <svg
                  className="w-8 h-8"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25z"
                  />
                </svg>
              }
            />
            <StepCard
              step={3}
              title="Organized"
              description="A beautifully formatted Obsidian note appears with your transcript, summary, action items, and decisions. Recording saved to Google Drive."
              icon={
                <svg
                  className="w-8 h-8"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              }
            />
          </div>
        </div>
      </section>

      {/* Privacy */}
      <section id="privacy" className="py-24 px-6">
        <div className="max-w-5xl mx-auto">
          <div className="glass rounded-2xl p-8 sm:p-12 text-center">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-teal/10 text-teal mb-6">
              <svg
                className="w-8 h-8"
                fill="none"
                viewBox="0 0 24 24"
                strokeWidth={1.5}
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                />
              </svg>
            </div>
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              Your data stays{" "}
              <span className="text-teal">yours.</span>
            </h2>
            <p className="text-muted text-lg max-w-2xl mx-auto mb-8">
              All AI processing runs on your Mac. WhisperX transcribes audio
              on your hardware. Ollama extracts metadata locally. No audio is
              sent to external servers. Recordings save to your Google Drive.
              Notes go straight to your Obsidian vault. Speaker diarization
              uses a one-time model download from HuggingFace. The code is
              open source so you can verify every line.
            </p>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-6 max-w-2xl mx-auto">
              <div className="text-center">
                <div className="text-2xl font-bold text-teal">0</div>
                <div className="text-sm text-muted">Audio uploaded</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-teal">0</div>
                <div className="text-sm text-muted">Accounts needed</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-teal">0</div>
                <div className="text-sm text-muted">Data collected</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-teal">100%</div>
                <div className="text-sm text-muted">Open source</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Tech Stack */}
      <section className="py-24 px-6">
        <div className="max-w-5xl mx-auto text-center">
          <h2 className="text-3xl sm:text-4xl font-bold mb-4">
            Built on proven tools.
          </h2>
          <p className="text-muted text-lg max-w-xl mx-auto mb-12">
            No custom models. No proprietary formats. Just best-in-class open
            source tools wired together.
          </p>
          <div className="flex flex-wrap justify-center gap-4">
            <TechBadge name="WhisperX" />
            <TechBadge name="Ollama" />
            <TechBadge name="pyannote" />
            <TechBadge name="Raycast" />
            <TechBadge name="Obsidian" />
            <TechBadge name="ScreenCaptureKit" />
            <TechBadge name="Google Drive" />
            <TechBadge name="ffmpeg" />
          </div>
        </div>
      </section>

      {/* Install */}
      <section id="install" className="py-24 px-6 gradient-radial">
        <div className="max-w-3xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              One command. Done.
            </h2>
            <p className="text-muted text-lg">
              macOS 12.3+ required. The installer handles everything.
            </p>
          </div>

          <div className="space-y-6">
            <InstallStep
              step={1}
              title="Run the installer"
              code="curl -fsSL https://memoant.com/install.sh | bash"
            />
            <InstallStep
              step={2}
              title="Add your HuggingFace token (optional, for speaker labels)"
              code={`# Get a token from huggingface.co/settings/tokens
# Accept terms at huggingface.co/pyannote/speaker-diarization-3.1
# Add to ~/.env: HF_TOKEN=hf_your_token_here`}
            />
            <InstallStep
              step={3}
              title="Grant screen recording permission"
              code={`# System Settings > Privacy & Security > Screen Recording
# Enable: Terminal and/or Raycast`}
            />
          </div>

          <div className="mt-12 text-center">
            <p className="text-muted text-sm">
              Need help? Check the{" "}
              <a
                href="https://github.com/kylnor/memoant#readme"
                className="text-coral hover:underline"
                target="_blank"
                rel="noopener noreferrer"
              >
                full README
              </a>{" "}
              for troubleshooting and configuration options.
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-6 border-t border-border">
        <div className="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="text-xl font-bold">memoant</span>
          </div>
          <div className="text-sm text-muted text-center">
            Built by{" "}
            <a
              href="https://github.com/kylenorthup"
              className="text-foreground hover:text-coral transition-colors"
              target="_blank"
              rel="noopener noreferrer"
            >
              Kyle Northup
            </a>
            {" "}&middot; MIT License &middot; &copy; {new Date().getFullYear()}
          </div>
          <a
            href="https://github.com/kylnor/memoant"
            target="_blank"
            rel="noopener noreferrer"
            className="text-muted hover:text-foreground transition-colors"
          >
            <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
            </svg>
          </a>
        </div>
      </footer>
    </div>
  );
}

function InstallStep({
  step,
  title,
  code,
}: {
  step: number;
  title: string;
  code: string;
}) {
  return (
    <div className="glass rounded-xl overflow-hidden">
      <div className="flex items-center gap-3 px-5 py-3 border-b border-border">
        <span className="flex items-center justify-center w-6 h-6 rounded-full bg-coral/20 text-coral text-xs font-bold">
          {step}
        </span>
        <span className="text-sm font-medium">{title}</span>
      </div>
      <pre className="p-5 text-sm font-mono text-muted overflow-x-auto">
        <code>{code}</code>
      </pre>
    </div>
  );
}
