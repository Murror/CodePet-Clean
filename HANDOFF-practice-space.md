# Handoff — In-app Practice Space (feat/refactor-core)

Context for continuing in Claude Code. Branch: `feat/refactor-core`. The app is a
macOS SwiftUI + Firebase target, so it only builds in Xcode (`⌘R`) or `xcodebuild`.

## What this feature does
Users practice "vibe-coding" skills entirely in-app, on a SAFE throwaway sandbox —
never their real project. The user WRITES the prompt from scratch (graded), runs it
via their own local `claude`, then reviews the result. Claude does the mechanical
edit; the practice is writing the instruction + judging the output.

## Key principles (do not regress)
- NEVER run against / modify the user's real project. Practice = sandbox only.
- The USER writes the prompt from scratch. Don't pre-fill + auto-run (that's spectating).
- Reuse the user's local `claude` (their subscription) — no separate API key/billing.
- Coaching is rule-based (no extra LLM calls).

## Files added/changed (all UNVERIFIED against the compiler — build first)
- `codepet/Services/ClaudeCodeRunner.swift` (new) — spawns local `claude -p --output-format stream-json`, streams typed events.
- `codepet/Services/PracticeSandbox.swift` (new) — one shared mini "yoga-site" (Hero to extract, unguarded data load, unvalidated form, imgs missing alt). Materializes to `~/Library/Application Support/Codepet/PracticeSandbox`; `prepare()`/`reset()`.
- `codepet/Models/PracticePromptGrader.swift` (new) — rule-based prompt-quality grade.
- `codepet/Views/Skills/ExerciseWorkspaceView.swift` (new) — write-from-scratch + live grade + sandbox run + file preview + review. Presented as a large modal.
- `codepet/Views/Skills/RunForRealSection.swift` (new) — PromptPlayground's "Run for real" step (also defines `CodeExecutionView`); runs on the sandbox.
- `codepet/Views/Skills/PromptPlaygroundView.swift` — added `userPrompt` to `PlaygroundResultView`, renders `RunForRealSection` after grading.
- `codepet/Models/AppState.swift` — added `activeExercise: SkillChallenge?`.
- `codepet/Views/Tips/TipsTabView.swift` — exercise tap now sets `appState.activeExercise` (opens the modal) instead of `pendingChallengeContext`.
- `codepet/Views/MainTabView.swift` — renders `ExerciseWorkspaceView` as a centered modal (~50% width) when `activeExercise != nil`.
- `codepet/Views/Reflection/ReflectionTab.swift` — `companionOpen` param hides the session chat when the companion is open (dedupes two Nova panels).
- `codepet/Views/Skills/CompanionPanelView.swift` — earlier `PanelMode`/exercise-mode edits; this path is now DEAD CODE (exercises bypass the companion). Safe to delete.

## Next steps
1. Build in Xcode and fix any compile errors (top priority — none of this is compiler-verified).
2. Smoke test: Tips tab → tap an exercise → modal opens → write a prompt → Run → watch the feed → Reset.
3. Commit (only the practice-space files):
   ```
   git add codepet/Services/ClaudeCodeRunner.swift codepet/Services/PracticeSandbox.swift \
           codepet/Models/PracticePromptGrader.swift codepet/Models/AppState.swift \
           codepet/Views/Skills/ExerciseWorkspaceView.swift codepet/Views/Skills/RunForRealSection.swift \
           codepet/Views/Skills/PromptPlaygroundView.swift codepet/Views/Skills/CompanionPanelView.swift \
           codepet/Views/MainTabView.swift codepet/Views/Tips/TipsTabView.swift \
           codepet/Views/Reflection/ReflectionTab.swift
   git commit -m "In-app practice space: write-from-scratch prompts on a safe sandbox"
   ```
   (If `git` complains about `.git/index.lock`, `rm -f .git/index.lock` first.)

## Known follow-ups (not done)
- Real before/after diffs in the feed (hook events only carry the file path, not old/new content — snapshot the sandbox file pre-run to diff).
- Remove the dead exercise path in `CompanionPanelView.swift`.
- "Hooks not installed" state (skill auto-completion via NarrativeEnricher needs the user's `~/.claude` hooks).
- Expand `PracticeSandbox.primaryFile(forSkill:)` to point each skill at its specific file if exercises diverge.
