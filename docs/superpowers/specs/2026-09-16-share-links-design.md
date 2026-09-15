# Short-Lived Share Links for Offers & Invoices — Design

## Problem

Sharing an offer or invoice via WhatsApp currently calls
`Printing.sharePdf(bytes: ...)`. On Flutter web this frequently falls back
to inserting a `blob:https://...` URL as plain text into the WhatsApp
message instead of attaching the actual file. A `blob:` URL is only valid
inside the browser tab/session that created it — the recipient's browser
can never resolve it. In practice, every shared "link" is currently
broken for the recipient.

The user asked for a real 14-day-valid link, mentioning a JWT and a URL
shortener as the mechanism. Cloud Functions (needed for server-side JWT
verification or a shortener redirect) require Firebase's Blaze plan
(billing enabled), which the user explicitly declined for this project —
consistent with earlier decisions in this codebase to avoid any Firebase
feature requiring billing (e.g. choosing Cloudinary over Firebase Storage
for image uploads). This design achieves the same outcome — a short,
real, time-limited link — using only Firestore + Firebase Hosting, both
available on the free Spark plan.

## Approaches considered

**A. Firestore-native share links, PDF regenerated client-side on open
(recommended).** A new `shareLinks/{code}` document holds a small JSON
snapshot of exactly the data the PDF generator needs, plus an
`expiresAt` timestamp. Firestore Security Rules enforce the 14-day
expiry server-side (`resource.data.expiresAt > request.time`) — this is
just as strong a guarantee as a JWT's `exp` claim, without needing a
server to issue or verify a token. The short link *is* the Firestore
document ID, generated up front — there is no long URL to shorten
afterwards, so no separate "shortener" component is needed.

**B. Store the rendered PDF bytes (base64) in the same document.** Same
mechanism, but the doc holds the actual PDF instead of the data to
regenerate it. Simpler viewer (decode and display, no regeneration
logic), but Firestore documents are capped at 1 MiB and base64 inflates
size by ~33% — a multi-page offer with many positions could approach or
exceed that ceiling as offers grow. Rejected for headroom reasons.

**C. Wrap the existing (broken) blob-sharing with a free external
shortener (is.gd/tinyurl).** Doesn't fix the actual bug — a `blob:` URL
is tab-local regardless of how it's shortened, so the recipient still
can't open it. Rejected.

Approach **A** is the design below.

## Architecture

No Cloud Functions, no Firebase Storage. Three pieces, all within the
existing Firestore + Hosting setup:

1. A new `shareLinks/{code}` Firestore collection.
2. A short-code generator + "create share link" step, replacing the
   direct `Printing.sharePdf(bytes)` call in the offer and invoice share
   flows.
3. A new public route (`/s/:code`) in the existing GoRouter app that
   loads the snapshot, checks expiry, and renders the PDF inline via the
   `printing` package's `PdfPreview` widget (already a dependency,
   already handles web display + download/print).

```
Staff taps "Teilen"
  -> build snapshot (subset of order/offer fields, no PII beyond
     what the client already sees in the document itself)
  -> generate short code, write shareLinks/{code} with 14-day expiresAt
  -> message text gets "https://<hosting-domain>/s/{code}" appended
  -> WhatsApp opens with that link (via existing text-share flow)

Recipient opens the link (no login, no account)
  -> GoRouter loads /s/{code}, exempted from the auth redirect
  -> Firestore read of shareLinks/{code} (publicly allowed while
     resource.data.expiresAt > request.time; denied/not-found after)
  -> valid: regenerate the PDF in-browser from the snapshot using the
     existing OfferPdfGenerator/InvoicePdfGenerator code, show it in a
     PdfPreview
  -> expired or missing: a plain "Dieser Link ist abgelaufen" screen
```

## Data model

`shareLinks/{code}` (code: 8-character base62 random string, generated
client-side; collision probability is negligible for this document
volume and a retry-on-write-conflict is cheap insurance, not a
requirement):

- `type`: `'offer' | 'invoice'`
- `snapshot`: a JSON map holding only the fields the respective PDF
  generator needs to render the document — for offers this is already
  the existing `OfferData` shape (it was already designed as the
  minimal, client-safe input to `OfferPdfGenerator`); for invoices, a new
  equivalent minimal snapshot type is introduced mirroring `OfferData`'s
  shape, scoped to what `InvoicePdfGenerator` actually reads. Neither
  includes internal-only fields such as `userId`, `userEmail`, or staff
  notes that aren't already printed on the document.
- `createdAt`: `serverTimestamp()`
- `expiresAt`: `createdAt + 14 days`, computed client-side at write time
  from the local clock (a few seconds of clock drift is immaterial for a
  14-day window)
- `orderId`: the source order, for staff traceability only (not read by
  the public viewer)

The collection is write-once: no `update`/`delete` path is exposed.
Expired documents are simply left in place (they become permanently
unreadable per the rule below); the volume is low enough that this
needs no separate cleanup job.

## Firestore rule

```
match /shareLinks/{code} {
  allow read: if resource.data.expiresAt > request.time;
  allow create: if isAuthenticated();
  allow update, delete: if false;
}
```

`read` intentionally has no `isAuthenticated()` clause — the recipient
opening the link from WhatsApp has no session at all, anonymous or
otherwise, so the read must work for a fully unauthenticated request.
`create` requires the staff member to be signed in, same bar as every
other authenticated write in this app.

## Router change

`lib/router/app_router.dart`'s top-level `redirect` currently sends any
request with no signed-in Firebase user to `/login`, except the login
route itself. The new `/s/:code` route must be added to that exception
list (matched by prefix, `state.matchedLocation.startsWith('/s/')`) so an
anonymous visitor can load it without being bounced to the login screen.

## Client flow changes

- `lib/screens/offer/widgets/offer_share_dialog.dart`: `_sharePdf()` is
  replaced by a step that builds the `OfferData` snapshot (already
  assembled elsewhere in `create_offer_screen.dart` to call the PDF
  generator — reused, not rebuilt), writes the `shareLinks` doc, and
  appends the resulting short link to the message text before it's
  copied to the clipboard / opened in WhatsApp. The existing "PDF
  teilen" button label/flow stays; only its underlying action changes
  from "attach a PDF" to "share a link".
- `lib/screens/invoice/create_invoice_screen.dart`: the equivalent
  `_sharePdf`-style call (line ~549) gets the same treatment, using the
  new minimal invoice snapshot type described above.
- New screen, e.g. `lib/screens/share/shared_document_screen.dart`: reads
  `shareLinks/{code}`, branches on found+valid / expired / not-found,
  and on success calls the existing PDF generator with the snapshot data
  and renders the result in a `PdfPreview`.
- New route entry in `app_router.dart`: `GoRoute(path: '/s/:code', ...)`.

## Error / edge states on the public viewer

- Malformed/unknown code → same "Link ungültig oder abgelaufen" message
  as an expired one (don't leak whether a code ever existed).
- Firestore permission-denied (expired, per the rule) is caught and
  shown as the same message — it is indistinguishable from "never
  existed" by design, which is the correct behavior for an expiring
  link.

## Testing

- Unit test for the short-code generator (correct length/alphabet).
- Unit test for expiry-timestamp computation (createdAt + 14 days).
- Widget test for `SharedDocumentScreen`'s three branches (valid,
  expired, not-found), driven by a fake Firestore read.
- Manual check after deploy: open a freshly created link on a signed-out
  browser session, confirm the PDF renders; confirm the router does not
  bounce it to `/login`.

## Scope

Both offer-sharing and invoice-sharing get this treatment — both call
sites currently share raw PDF bytes and hit the identical `blob:` bug.
