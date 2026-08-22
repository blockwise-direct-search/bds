# Slides

`auto_initial_step_size_report.tex` is the source of the advisor-facing report.
It embeds the existing OptiProfiler-native PDFs directly; it does not redraw
their curves.

Build from this directory with:

```text
latexmk -xelatex auto_initial_step_size_report.tex
```

The tracked deliverables are the `.tex` source and the compiled `.pdf`.
