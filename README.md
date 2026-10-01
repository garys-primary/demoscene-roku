# Roku Virtual Gallery Dedicated to 90s and early 2000s Demoscene 
  
The private channel can be installed with this link:  https://my.roku.com/account/add/demo (enter code DEMO)  
    
This channel features a bit different approach to organizing SceneGraph.  
It contains storyline.brs that encodes exhibit flow as well as navigation.brs that encodes user navigation options in clean and easy to edit format.

Please enjoy your interactive journey!

## First run

1. Enable developer mode on a Roku TV and record its IP and developer password.
2. Copy `.env.example` to `.env`.
3. Fill in the Roku connection and media endpoint values.
4. Run `powershell -ExecutionPolicy Bypass -File scripts/package.ps1`.
5. Run `powershell -ExecutionPolicy Bypass -File scripts/deploy-tv.ps1`.

## Content configuration

Production hostnames are intentionally absent from source control. `content/catalog.template.json` and `manifest` contain placeholders; `scripts/package.ps1` replaces them with `MEDIA_BASE_URL` and `CATALOG_URL` from the ignored `.env` file. The rendered catalog is bundled as the offline fallback and is also used by `scripts/upload-media.ps1`.

## Project map

- `source/storyline.brs` — readable route tree.
- `source/navigation.brs` — screen registry and transitions.
- `components/screens/` — one SceneGraph component per screen.
- `content/` — catalog schema and local fixture.
- `infra/` — repeatable Ubuntu/nginx origin setup.
- `scripts/` — packaging, sideloading, encoding, upload, and validation.
- `docs/` — decisions, handoff state, and device checklist.


Made with love to code and to early CGI. (C) garys 2026