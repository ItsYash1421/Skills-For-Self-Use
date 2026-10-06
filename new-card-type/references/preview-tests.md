# Guard tests every new card copies (apps: `src/cards/__tests__/<x>Template.test.tsx`)

These are the tests that FAILED on the buggy code and pass on the fix — they are the reason the
bugs in `known-bugs.md` cannot come back silently. Adapt names/scene ids; keep the assertions.
Originals: iOS `src/cards/__tests__/missYouTemplate.test.tsx` and `thankYouPreview.test.tsx`
(same files on the Android branch). Preview components must accept `playing` and
`onSceneChange(sceneId)` props so these tests can observe them.

## 1. Every scene plays for its full length, through one loop (A1)
```tsx
it('plays every scene for its full length, and the intro again on loop', () => {
  jest.useFakeTimers();
  const started: Array<{scene: string; at: number}> = [];
  let tree: renderer.ReactTestRenderer | null = null;
  act(() => {
    tree = renderer.create(
      <XCardPreview content={content} playing
        onSceneChange={s => { if (started[started.length - 1]?.scene !== s) started.push({scene: s, at: Date.now()}); }} />,
    );
  });
  for (let i = 0; i < 1800; i++) act(() => { jest.advanceTimersByTime(50); });
  const order = started.map(s => s.scene);
  expect(order.slice(0, N + 2)).toEqual([...SCENES, SCENES[0], SCENES[1]]);
  const shortest = Math.min(...started.slice(0, N + 1).map((s, i) => started[i + 1].at - s.at));
  expect(shortest).toBeGreaterThan(MIN_SCENE_MS);
  act(() => tree!.unmount());
  jest.useRealTimers();
});
```
Use content where a LONG scene is followed by a SHORT one — that is exactly what the stale clock skipped.

## 2. Auto-play only — nothing tappable outside the controls (A3)
```tsx
it('plays on its own: only pause / mute / fullscreen take taps', () => {
  jest.useFakeTimers();
  let tree: renderer.ReactTestRenderer | null = null;
  act(() => { tree = renderer.create(<XCardPreview content={content} playing showMute onToggleMute={() => {}} />); });
  const tappable = () => {
    const controls = new Set(tree!.root.findAll(n => (n.type as any)?.name === 'CardPreviewControls').flatMap(c => c.findAll(() => true)));
    const blocked = (n: renderer.ReactTestInstance | null): boolean => !!n && (n.props.pointerEvents === 'none' || blocked(n.parent));
    return tree!.root.findAll(n => typeof n.type === 'string' && !controls.has(n)
      && (typeof n.props.onPress === 'function' || typeof n.props.onResponderRelease === 'function') && !blocked(n));
  };
  for (let i = 0; i < 1500; i++) {
    act(() => { jest.advanceTimersByTime(50); });
    if (i % 25 === 0) expect(tappable()).toHaveLength(0);
  }
  act(() => tree!.unmount());
  jest.useRealTimers();
});
```

## 3. A slow frame pauses instead of skipping (A2)
At the start of the heaviest scene, jump the wall clock: `jest.setSystemTime(start + 1500)`, then
assert the scene's first beat still happens > 1200 ms after the jump and lasts its full length.
Only meaningful for rAF/wall-clock timelines; setTimeout-per-scene previews (Thank You) skip it.

## 4. Each item once, no wrap (A4)
Record which item is on top every 50 ms through the walking scene; assert the sequence is
`[item1, item2, …, itemN]` with no item reappearing before the next scene starts, and that the
scene lasts lead + max(1, n−1)·step + tail.

## 5. Measured text fit (A6)
Pure tests of the fit search: largest size whose measured layout fits; keeps the design size when
it already fits; floors at min when nothing fits; measures again when the scale changes.

## 6. Whole board visible (A7)
Assert the preview window constants show the full board height (e.g. `CONTENT_TOP === 0`,
frame height = board height × scale) — a crop must be a deliberate, tested decision.

## 7. Song (A8, A9)
- Flow test: with the catalog music OFF, preview `music` is the bundled FILE module and `showMute` is true.
- Preview test: `onReplay`/`restartKey` does not fire on first play, fires when the story loops to the first scene.

## 7b. Re-opening the preview starts card + song over (A13)
Render with `playing`, advance into a middle scene, `update(playing=false)` then `update(playing=true)`: the scene is the first one again, `onReplay` fired exactly once, a paused preview is unpaused, and the first scene plays its FULL length (clock reset with `runKey`). Originals in `thankYouPreview.test.tsx` / `missYouTemplate.test.tsx`.

## 8. Greeting + content (A10)
`defaultLetter(name)` greets the name; changing the name rewrites only an untouched auto greeting;
an edited greeting is never overwritten; `draftFromContent` upgrades the old constant.

## Web equivalents (cards-fe, vitest)
- `templates/<id>/motion.test.tsx`: auto steps fire in order with `preview` on and do NOT fire with it off; pausing freezes them.
- `templates/<id>/content.test.ts`: greeting rules (same as §8).
- `templates/og.test.ts`: the OG tile renders for the new template and falls back for a bad name.
- Shared already covered (don't duplicate): Replay restarts the song (`SceneRunner`, `audioController` tests), PreviewStage, PhotosScene.
