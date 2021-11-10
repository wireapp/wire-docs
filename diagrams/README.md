# Diagrams with Mermaid

* try them out on https://mermaid.live/
* see syntax on https://mermaid-js.github.io/mermaid/#/sequenceDiagram
* locally compile them with `./mmdc` to `svg`: [mmdc / mermaid-cli](https://github.com/mermaid-js/mermaid-cli)
    * `npm install @mermaid-js/mermaid-cli`
* see mermaid [integrations](https://mermaid-js.github.io/mermaid/#/./integrations)
* type 'make watch-filename.mmd' if you have `mmdc` and `okular` and `entr` locally available for one option of a "save + autoreload" workflow.

## TODO

It would be good to combine mermaid tooling with sphinx tooling.

Possibly this could be done via 'kroki.io' and the sphinx-kroki
integration: https://pypi.org/project/sphinxcontrib-kroki/ (as that
would also allow other kinds of diagrams to be created as code)

Or directly via the sphinx-mermaid integration: https://pypi.org/project/sphinxcontrib-mermaid/
