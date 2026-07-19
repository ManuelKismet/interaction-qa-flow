# Interaction QA Flow

Interaction QA Flow is a free, local-first browser tool for mapping shared questions, participant-specific questions, live answers, and unexpected follow-up branches.

It is designed for conversations and workflows where you start with a planned question path, switch between participants, and capture new follow-up questions when an answer reveals something unexpected.

## Use Cases

- Customer support troubleshooting
- Incident reports
- Audit or compliance checks
- Requirements discovery
- Consulting or discovery calls
- QA and exploratory testing notes

## Features

- Prepared question path
- Multiple participants
- Shared questions with separate answers per participant
- Participant-specific questions
- Answer fields for each question
- Follow-up branches from any answer
- Nested follow-up branches
- Editable questions and answers
- Question deletion
- Local autosave in the browser
- Autosave history summary
- Named JSON export files
- JSON import to reopen or share flows
- CSV export
- Read-only report view
- Print / Save PDF support
- One built-in default template
- Local custom templates for repeated question sets
- Template import and export
- No login or backend required

## Privacy

This tool stores data locally in your browser using `localStorage`. Nothing is uploaded by the app. A flow only leaves your device if you export and share a JSON, CSV, or PDF file yourself.

If you clear browser storage, local autosaved data may be removed. Use **Save JSON file** for anything important.

## How To Use

1. Open `index.html` in a browser.
2. Add shared questions when every participant should answer the same prompt.
3. Add participants and switch between them to capture separate answers.
4. Add participant questions when only the active participant needs that prompt.
5. Use **Add follow-up** to create a participant-specific branch.
6. Use **Report view** for a read-only summary of the active participant view.
7. Use **Save JSON file** to keep a reusable copy.
8. Use **Open JSON file** to reopen a saved flow.

## Templates

The app includes one default template for a general interaction QA flow.

You can also save your own recurring question sets as local templates. Custom templates are stored in your browser, keep the question and branch structure, and clear answer text so sensitive responses are not carried into the reusable template.

Use **Export templates** and **Import templates** to share template sets with another browser, device, or team. Loading a template replaces the current flow after confirmation when data already exists.

## Hosting

This is a static site. You can host it with:

- GitHub Pages
- Cloudflare Pages
- Netlify
- Vercel
- Any static web server

No build step is required.

## Development

The app is currently a single self-contained HTML file:

- `index.html`

A quick JavaScript syntax check can be run with:

```sh
node -e 'const fs=require("fs"); const html=fs.readFileSync("index.html","utf8"); for (const [,code] of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Function(code); console.log("inline script syntax ok");'
```

## License

MIT. See `LICENSE`.
