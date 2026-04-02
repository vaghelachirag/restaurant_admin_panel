// This stub satisfies the conditional import on non-web platforms.
// On web, dart:html is used instead and AudioElement is the real browser class.

/// No-op AudioElement stub used on mobile/desktop builds.
class AudioElement {
  AudioElement(String src);
  void play() {}
}