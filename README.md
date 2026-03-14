# Dev Containers
Seamless sharing and version-control for you dev containers.

## Installation
`.devcontainer/` should not exist yet. This repo is intended to be a submodule at `.devcontainer/` and contain all dev containers for a project.
```bash
git submodule add git@github.com:ReubenBeeler/vscode-dev-containers.git .devcontainer/
```

## Notes
Don't look in `.devcontainer/`... it is a symlink to allow the dev containers extension to see the repo-level dev containers. The dev containers are repo-level to enable use as a submodule -- see [Installation](#installation).
