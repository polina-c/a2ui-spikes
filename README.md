# a2ui4w

POC for integrating a2ui with WorldPress and Wix.

## References

1. Web llm: https://github.com/mlc-ai/web-llm
2. WorldPress: https://wordpress.org 

    - Plugin: https://wordpress.org/plugins/ai-engine/ 
    - Example: https://meowapps.com/ai-engine/ 
  
3. Wix: https://www.wix.com/
4. Jaspr: https://jaspr.site
5. Flutter GenUI: https://github.com/flutter/genui

## Core artifacts

### Jaspr

[`jaspr/genui`](jaspr/genui) is [Flutter GenUI](https://github.com/flutter/genui)
ported to Dart/Jaspr: a model sends A2UI messages and the package renders them
as a live page. [`jaspr/simple_chat`](jaspr/simple_chat) is the Simple Chat
sample built on it, with the model running in the browser through WebLLM, so
there is no key and no server. See
[jaspr/simple_chat/README.md](jaspr/simple_chat/README.md) to run it.

### Wix

[`wix/minimal`](wix/minimal) is a Wix page with a chat whose model runs in the
visitor's browser, written as a plain JavaScript custom element.
[`wix/jaspr`](wix/jaspr) is the same site in Jaspr: the same answers from the
same facts, with the rules that ground them written in Dart and tested without
a browser, and the WebLLM client shared with `jaspr/simple_chat`. See
[wix/jaspr/README.md](wix/jaspr/README.md) to build it and put it on a page.

published site: https://polina27182.wixsite.com/my-site-1

editor: https://polina27182-my-site-1.editor.wix.com/edit/od/0f803c83-0cfd-4c8e-9eec-c39bca68be9a?metaSiteId=d2268acf-fb94-4413-8bef-fb1841faab00&editorSessionId=05a0f065-5d89-41e8-ae9c-85d7a4e841b5


