---
name: coding
description: >
  Development helper for the Veo Chat application. Use this skill when the user 
  asks about Veo Chat workflows, running tests, creating components, or 
  adhering to repository standards.
---

# Development Helper

This skill provides workflows and best practices specific to the `veochat` repository.

## Shared components

UI components shared accross applications, should be placed to 
simple_chat/shared_ui.

## Sets of constants

For repeating constants use structures like this:

```dart
class _Json {
  static const String storyTitle = 'storyTitle';
  static const String storyText = 'storyText';
  static const String storyScriptYaml = 'storyScriptYaml';
}
```
