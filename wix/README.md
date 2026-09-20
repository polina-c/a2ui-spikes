# Wix AI chat

## Background

[WebLLM](https://webllm.mlc.ai/) is a high-performance, in-browser, free LLM.

[Wix](https://www.wix.com/) is a website builder for small businesses and individuals.

[A2UI](https://a2ui.org/) is a framework for enhancing AI with generated UI.

## Question 1

Is it possible to enable a Wix site to provide a chat that uses WebLLM in the browser, and also leverages the A2UI, so that the business that created the site can offer a chat to their visitors, to answer their questions about the business's products and services?

## Experiment 1

Yes, it is easy to run a WebLLM chat on a Wix page, with RAG over the [facts 
about the business](./minimal/content/knowledge.js).

[`wix/minimal`](minimal/README.md) is a Wix page with a chat whose model runs in the
visitor's browser, written as a plain JavaScript custom element.

Published site: https://polina27182.wixsite.com/my-site-1

Editor for the site: https://polina27182-my-site-1.editor.wix.com/edit/od/0f803c83-0cfd-4c8e-9eec-c39bca68be9a?metaSiteId=d2268acf-fb94-4413-8bef-fb1841faab00&editorSessionId=05a0f065-5d89-41e8-ae9c-85d7a4e841b5

## Question 2

Can A2UI be leveraged for a local free LLM?

Initial implementation fails because of context size.

To answer the question, we need to figure out simple enough catalog and efficient format that can run with a free local model.

Options for local models:

- https://github.com/eugeneyan/open-llms
- https://www.instaclustr.com/education/open-source-ai/top-7-open-source-llms-for-2026/

Next step: run evals for a2ui on some local free models.
