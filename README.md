# Spot 📍

Find your people at real places. A map of third spaces near campus, with a simple way to post "I'll be here" so friends can join.

## What's in this repo

- `index.html` — the full app (frontend + Supabase integration), single file, no build step required.
- `schema.sql` — run this once in your Supabase project's SQL Editor to set up the database (profiles, friends, favorites, posts).

## Setup

1. Create a free project at [supabase.com](https://supabase.com)
2. In the Supabase SQL Editor, run `schema.sql`
3. In Supabase → Settings → API, copy your Project URL and anon public key
4. Open `index.html`, find the `SUPABASE_URL` and `SUPABASE_ANON_KEY` constants near the top of the `<script>` tag, and paste your values in
5. Deploy to [Vercel](https://vercel.com) — import this repo, no build configuration needed, it's a static file

## Stack

- Plain HTML/CSS/JS (no framework, no build step)
- Supabase (auth + Postgres database)
- Deployed on Vercel
