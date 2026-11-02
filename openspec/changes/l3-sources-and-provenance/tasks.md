# L3 — tasks

The domain and the request path are in. The interface is not, and the difference is
stated on every line rather than blurred.

- [x] A source has a kind, a locator, a stable id and its revisions.
      `SourceLedgerTests`
- [x] A reference is a pointer, not a copy: a pasted link fetches nothing and an
      image is not understood until asked. `SourceLedgerTests`
- [x] A quote keeps a locator that survives the source moving, and a citation
      towards a source or revision that is not there is refused. `SourceLedgerTests`
- [x] A claim can be verified, and verification requires an observation and an
      author. There is no API that sets a badge without them. `SourceLedgerTests`
- [x] A new revision flags what it supersedes and never re-points a citation.
      `SourceLedgerTests`
- [x] A failed extraction keeps the previous good version active. `SourceLedgerTests`
- [x] A removed source never deletes the claim; the citation stays, marked.
      `SourceLedgerTests`
- [x] The context budget is measured on the real request path, omissions are
      counted, and a required item is never dropped to fit. `ContextProjectionTests`,
      `AppleAdapterTests`
- [x] **AI-12 AC01–03** the measured projection is the payload, a required overflow
      refuses before generation, the narrowed scope survives both Apple conversion
      paths, and the attribution panel states how many objects were read and omitted.
      `ContextProjectionTests`, `AppleAdapterTests`, `ProposalAttributionTests`
- [x] A local-only projection cannot be sent. `ContextProjectionTests`
- [x] A source is attached through a validated command in one transaction, and a
      transaction that fails halfway attaches nothing. `SourceCommandTests`
- [x] Intelligence is refused `attachSource`, `addCitation`, `recordVerification` and
      `removeSource` outright. A model that could add a citation would manufacture the
      appearance of support, and one that could record a verification could award
      itself a badge. `SourceCommandTests`
- [x] A chip on the claim shows what state its sources are in, one per source, read
      from the ledger and never cached. `SourceChipTests`
- [x] A file with no text cannot be imported as a good revision, and the previous
      version stays active. `SourceCommandTests`
- [x] The `.kollio` schema declares the ledger, the version is bumped to 2, and a
      test fails if the codec writes a key the schema does not declare.
- [x] A file is read from disk by kind, and says honestly what came out.
      `SourceReaderTests`
- [x] **AC01** a CSV with quotes, commas and newlines parses correctly.
- [x] **AC02** a PDF with no text layer is marked as having no text.
- [x] **AC03** a pasted link is never fetched, and the refusal happens before any
      file access rather than surfacing as "the file could not be opened".
- [x] An image is digested and nothing else: no description, no OCR.
- [x] An empty file, a non-UTF-8 file and an unreadable kind are each reported as
      what they are, never as an empty success.
- [x] A file chooser in the contextual actions of a claim. `NSOpenPanel`,
      cancellable, nothing read until a file is chosen.
- [x] Reading the chosen file and importing its revision in one transaction, so a
      file that cannot be read leaves nothing behind. `SourceChipTests`
- [x] A file with no text is attached and announced as *not read*, never as a
      successful import.
- [x] The same file twice is two sources keyed by content, not two copies of one.
- [x] A failed import is recorded rather than refused, so the chip can say so, and a
      usable earlier revision stays the one being read. `SourceLedgerTests`
- [x] Choosing a passage inside the source: the selected lines become the quote
      verbatim and the locator, and opening the citation returns to them.
      `SourceChipTests`
- [x] An out-of-range, empty or unknown selection cites nothing. An inverted range
      cannot be refused because it traps in Swift, which the test now says.
- [x] A CSV is previewed as columns with headers, not as raw commas, and the cap is
      stated with the real row count. `SourceChipTests`
- [x] The preview is parsed from the revision on record, never re-read from disk.
      `SourceChipTests`
- [x] A file opens in the system reader (QuickLook) beside the canvas, so a long
      PDF is a document Apple already builds rather than a worse viewer written
      here. `SourcePreviewPanel`
- [ ] The QuickLook panel is not covered by a test: it is a system panel and
      asserting on it would only test Apple. Its absence is stated rather than
      covered by a pretend test.
- [x] Opening a citation back at its passage, from the exact revision it was read
      against, beside the claim. `SourceChipTests`
- [x] Recording a verification from the interface, and only with an observation:
      an empty one is refused and the draft is kept. `SourceChipTests`
- [x] A page locator shows no passage rather than a slice of joined text that would
      point at the wrong place. `SourceChipTests`
- [x] A citation on a superseded revision says so in the interface.
- [x] Import and extraction by kind: text, Markdown, PDF, CSV, image. A link is
      never fetched and an image is never understood without being asked.
      `SourceReaderTests`
- [x] A claim has an explicit scope, and a claim with an empty scope is refused
      rather than read as "everything". `ClaimLedgerTests`
- [x] **AC01** a constraint only blocks inside its own scope.
- [x] **AC02** not applicable is not satisfied, and blocks nothing either.
- [x] **AC03** supported is not absolute truth: the vocabulary has no case meaning
      "true", and every non-open verdict carries an observation and an author.
- [x] Assessing a hypothesis and resolving a constraint are refused on each other's
      claims, and neither ever touches the other.
- [x] Contradictory scopes are surfaced for a person to resolve, not settled by
      picking a winner.
- [x] Intelligence may suggest a claim, but may not record how it stands and may not
      arrive pre-resolved. `ClaimLedgerTests`
- [x] The `.kollio` schema declares the claims ledger and the version is 3.
- [x] Stating a claim from the interface: role, criterion, and a scope taken from
      the current selection. `ClaimInterfaceTests`
- [x] An empty scope states nothing, says why, and keeps the draft.
- [x] A stance needs an observation, and a refused one leaves the sentence alone.
- [x] The stances offered depend on the role: a constraint cannot be refuted and a
      hypothesis cannot be satisfied, and a verdict from the other vocabulary is
      resolved to open rather than invented. `ClaimInterfaceTests`
- [ ] Asking for precision when two scopes overlap, in the interface.
- [ ] A context view lists sources and quotes, reading only from the ledger.
- [ ] A knowledge view is derived, never authored twice.
- [ ] Retrieval returns its result *and* its absence.
- [ ] A presentable object carries an external link that opens outside the app.
- [ ] The interface that shows the projection matches the built payload. The
      payload is measured and reported; nothing shows it to a person yet.

## Design pressure worth recording now

`AI-12` is implemented without retrieval or summarisation: required context is
prioritised, optional context is narrowed with an explicit record, and an essential
overflow asks for framing instead of producing an answer about less. Counts are
declared as characters because the framework does not expose its tokenizer. The
remaining debt is visual: a person has not inspected the scope row in both languages
and appearances.
