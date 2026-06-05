import Foundation

/// A self-contained practice project Codepet ships and materializes on disk so
/// users can practice skills WITHOUT touching their real code.
///
/// One shared mini "yoga-site" covers all four skills (a Hero block to extract,
/// an unguarded data load, an unvalidated form, images missing alt text). On
/// each exercise we hand `claude` this throwaway copy — never the user's project.
/// `reset()` restores the pristine version so retries always start clean.
enum PracticeSandbox {

    /// Where the working copy lives. Uses the real home (not the sandbox
    /// container) for consistency with the rest of the app.
    static var rootURL: URL {
        RealHome.url.appendingPathComponent("Library/Application Support/Codepet/PracticeSandbox/yoga-site")
    }

    static var path: String { rootURL.path }

    /// Ensure the sandbox exists on disk; returns its absolute path.
    /// - Parameter reset: when true, wipes any existing copy first.
    @discardableResult
    static func prepare(reset: Bool = false) throws -> String {
        let fm = FileManager.default
        if reset, fm.fileExists(atPath: rootURL.path) {
            try fm.removeItem(at: rootURL)
        }
        if !fm.fileExists(atPath: rootURL.path) {
            for (relativePath, contents) in files {
                let fileURL = rootURL.appendingPathComponent(relativePath)
                try fm.createDirectory(at: fileURL.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try contents.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
        return rootURL.path
    }

    /// Restore the pristine project (used by the "Reset" button).
    @discardableResult
    static func reset() throws -> String {
        try prepare(reset: true)
    }

    /// Read a file's current contents from the working copy (for previews/diffs).
    static func currentContents(of relativePath: String) -> String? {
        try? String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// The most relevant file to show for a given skill, so the user knows what
    /// they're working with before writing a prompt.
    static func primaryFile(forSkill skillId: String) -> String {
        // Every skill's target currently lives in page.tsx; this indirection lets
        // us point individual skills at other files later without UI changes.
        switch skillId {
        case "component_composition", "loading_error_states",
             "form_validation_ux", "accessibility_basics":
            return "app/page.tsx"
        default:
            return "app/page.tsx"
        }
    }

    // MARK: - Bundled project (materialized on disk at runtime)

    private static let files: [String: String] = [
        "app/page.tsx": pageTSX,
        "app/lib/site-data.ts": siteDataTS,
        "package.json": packageJSON,
        "README.md": readme
    ]

    private static let pageTSX = """
    import Image from "next/image";
    import Link from "next/link";
    import { classes, loadClasses } from "@/app/lib/site-data";

    export default async function HomePage() {
      // Data is loaded with no error handling and no loading state.
      const schedule = await loadClasses();

      return (
        <main className="home">
          {/* ---- Hero (a large inline block — a good candidate to extract) ---- */}
          <section className="hero">
            <div className="hero-text">
              <h1>Breathe. Move. Belong.</h1>
              <p>
                A neighborhood yoga studio for every body. Drop in for a class
                or join the community — no experience required.
              </p>
              <Link href="/schedule" className="cta">View the schedule</Link>
            </div>
            <div className="hero-art">
              <Image src="/hero.jpg" width={520} height={360} />
            </div>
          </section>

          {/* ---- Class list (rendered from loaded data) ---- */}
          <section className="classes">
            <h2>This week</h2>
            <ul>
              {schedule.map((c) => (
                <li key={c.id}>
                  <img src={c.photo} width={80} height={80} />
                  <div>
                    <strong>{c.name}</strong>
                    <span>{c.time} · {c.teacher}</span>
                  </div>
                </li>
              ))}
            </ul>
          </section>

          {/* ---- Contact form (no validation yet) ---- */}
          <section className="contact">
            <h2>Ask us anything</h2>
            <form action="/api/contact" method="post">
              <input name="name" placeholder="Your name" />
              <input name="email" placeholder="Email" />
              <textarea name="message" placeholder="Message" />
              <button type="submit">Send</button>
            </form>
          </section>
        </main>
      );
    }
    """

    private static let siteDataTS = """
    export type YogaClass = {
      id: string;
      name: string;
      time: string;
      teacher: string;
      photo: string;
    };

    const SCHEDULE: YogaClass[] = [
      { id: "vin-mon", name: "Vinyasa Flow", time: "Mon 6:00pm", teacher: "Mara",  photo: "/c1.jpg" },
      { id: "yin-tue", name: "Yin & Restore", time: "Tue 7:30am", teacher: "Devin", photo: "/c2.jpg" },
      { id: "pow-wed", name: "Power Hour",    time: "Wed 12:00pm", teacher: "Sam",   photo: "/c3.jpg" },
    ];

    // Simulates a network fetch — sometimes the network is slow, sometimes it fails.
    export async function loadClasses(): Promise<YogaClass[]> {
      await new Promise((r) => setTimeout(r, 400));
      return SCHEDULE;
    }

    export const classes = SCHEDULE;
    """

    private static let packageJSON = """
    {
      "name": "yoga-site",
      "version": "0.1.0",
      "private": true,
      "description": "A tiny practice project for Codepet exercises. Safe to change — it is a throwaway copy.",
      "dependencies": {
        "next": "14.0.0",
        "react": "18.2.0",
        "react-dom": "18.2.0"
      }
    }
    """

    private static let readme = """
    # yoga-site (practice sandbox)

    This is a **throwaway copy** Codepet created so you can practice safely.
    Nothing you do here touches your real projects. Reset it anytime from the app.
    """
}
