# Roku Demoscene Virtual Gallery
  
The private channel can be installed with this link:  https://my.roku.com/account/add/demo (enter code DEMO)  

Please enjoy your interactive journey!

## First run

1. Enable developer mode on a Roku TV and record its IP and developer password.
2. Copy `.env.example` to `.env`.
3. Fill in the Roku connection and media endpoint values.
4. Run `powershell -ExecutionPolicy Bypass -File scripts/package.ps1`.
5. Run `powershell -ExecutionPolicy Bypass -File scripts/deploy-tv.ps1`.

## Server

You can install your own tiny streaming server with this repo and host your media.  
Please refer to `content\catalog.template.json` for required file names and descriptions.  
To install the server, please configure your AWS and `.env` and run `infra\new-lightsail-origin.ps1`   
This will create a Lighsail instance ready to serve your files.  
  
## Content configuration

The media used is too large to be included here.  
It has been rendered from emulators.  
You can uplaod your own media to `media-src` and run:  
- `scripts\prepare-media.ps1` to chop videos into chunks and playlists (requires ffmpeg)  
- `scripts\upload-media.ps1` to upload playlists to the server.   
  
Made with love to code and to early CGI. (C) garys 2026
