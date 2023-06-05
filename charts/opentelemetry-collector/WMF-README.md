
This is vendored from
https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector.

README.md is the upstream readme file. In addition, in the upstream repo but not copied here, see
UPGRADING.md and the examples/ directory.


Changes from upstream:

* .fixturectl.yml and .fixtures.yaml are added, to customize WMF CI.

* `mode: daemonset` is set in values.yaml, because the chart doesn't build without it. (We'd be fine
  just setting the mode in the helmfile, but then it would fail to validate as-is in our CI. For
  now this is fine, as we only need one setting in production anyway. If that changes in the
  future, we could consider leaving the default `mode: ""` as upstream does, and addressing the CI
  issue differently.)