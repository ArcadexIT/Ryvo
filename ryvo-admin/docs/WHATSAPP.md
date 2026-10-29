# WhatsApp booking setup

Riders can book Ride, Bid, or Parcel by texting WhatsApp. Drivers still use the driver app. WhatsApp is another client of the same job API, not a second backend.

```
Rider WhatsApp → Twilio → POST /api/v1/webhooks/whatsapp
                         → Ryvo bot (keywords + optional OpenAI)
                         → same create-job API
                         → driver app matching
                         → status replies back on WhatsApp
```

---

## How a booking works

1. Rider messages the Ryvo WhatsApp number.
2. Twilio POSTs `From` + `Body` to `https://your-domain/api/v1/webhooks/whatsapp`.
3. If **WhatsApp booking** is off in Admin → Settings, Ryvo ignores the message.
4. Ryvo finds or creates a `WhatsAppSession` for that phone, then collects:
   - Ride / Bid / Parcel
   - Pickup address (geocoded with the Maps key)
   - Dropoff address
   - Parcel only: `Name, phone, size` (`small` / `medium` / `large`)
   - Class number (`1` = Ryvo Go, or Parcel Bike, etc.)
   - Bid only: offered price
   - **YES** to confirm
5. Ryvo creates or reuses a customer from that WhatsApp phone, then creates a normal `Job`. Payment is **cash**. Channel is `whatsapp`.
6. Nearby drivers get the request in the driver app.
7. Ryvo texts the rider when a driver accepts, or if no driver is found.

OpenAI is optional. With no `OPENAI_API_KEY`, the rider must use those keywords. With a key, free-form text can still be mapped onto the same steps.

Say **hi**, **hello**, **start**, **menu**, or **help** to reset and get the welcome text.

---

## Setup, step by step

### 1. Use the same Twilio account as SMS OTP

In [Twilio Console](https://console.twilio.com), copy:

- Account SID
- Auth Token

These already go in `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`.

### 2. Turn on WhatsApp (sandbox first)

For testing:

1. Twilio Console → **Messaging → Try it out → Send a WhatsApp message**.
2. Join the sandbox: from your phone, send the join code (for example `join <word>`) to the Twilio sandbox number.
3. Copy the sandbox from-number, usually `+14155238886`.

For live riders later you need a Twilio WhatsApp sender (approved business number). Until then, only phones that joined the sandbox can message you.

### 3. Put the WhatsApp from-number on the API

Local: `ryvo-admin/apps/api/.env`  
Server: `ryvo-admin/apps/api/.env.production`

```bash
TWILIO_ACCOUNT_SID=ACxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxx
TWILIO_PHONE_NUMBER=+1...          # SMS OTP (already used)
TWILIO_WHATSAPP_FROM=+14155238886  # sandbox or approved WhatsApp number
```

Restart the API. Logs should mention WhatsApp if this is set.

`bash ryvo-admin/docker/install.sh` already asks for this and writes it.

### 4. Point Twilio at Ryvo

In the WhatsApp sandbox (or the live sender’s messaging webhook):

| Field | Value |
|---|---|
| When a message comes in | `https://your-domain/api/v1/webhooks/whatsapp` |
| Method | HTTP POST |

Local test: expose port 4000 with ngrok, then use `https://xxxx.ngrok.io/api/v1/webhooks/whatsapp`.

The webhook is public (no JWT). Twilio sends form fields `From` and `Body`.

### 5. Turn the feature on in Admin

Admin → **Settings → Ride, bid, parcel, WhatsApp**:

1. **WhatsApp booking** → On. If this is Off, messages are ignored.
2. Optional: edit **WhatsApp welcome text**.

### 6. Optional: natural language

In the API env:

```bash
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o-mini
```

Leave empty to keep the keyword bot.

Also set the **Google Maps** key in Admin (or `GOOGLE_MAPS_API_KEY`). Without it, Ryvo still accepts the typed address but falls back to Birmingham coordinates, so matching will be wrong.

### 7. Test the conversation

From a phone that joined the sandbox:

```text
You: Hi
Bot: Hi, this is RYVO. Reply with Ride, Bid, or Parcel...

You: Ride
Bot: Great, taxi it is. Send your pickup address.

You: 221 Baker Street, London
Bot: Pickup set to ... Now send the dropoff address.

You: 10 Downing Street, London
Bot: Choose a class by number:
     1. Ryvo Go
     2. Comfort
     ...

You: 1
Bot: Confirm taxi Ryvo Go from ... to ... for 8.50? Reply YES to book.

You: YES
Bot: Booked RYV-xxxx. We are looking for a driver.
```

**Bid:** after the class, send a number (your offer), then YES.

**Parcel:** after dropoff, send `Sara, +447700900123, small`, then the parcel class, then YES.

A driver who is online and nearby should see the job. When they accept, WhatsApp says they are on the way. If nobody accepts, WhatsApp says no drivers were available.

---

## Going live (after sandbox)

1. Buy or register a WhatsApp sender in Twilio (Meta Business verification may be required).
2. Replace `TWILIO_WHATSAPP_FROM` with that number and restart the API.
3. Point the live sender webhook at the same URL: `https://your-domain/api/v1/webhooks/whatsapp`.
4. Approve outbound templates in Twilio/Meta for status messages (driver assigned, no driver). Inbound booking replies can stay free-form.
5. Keep **WhatsApp booking** On in Admin.

---

## What you should know

- Drivers never use WhatsApp. They use the driver app.
- WhatsApp jobs are **cash**. There is no Stripe hold from chat.
- A new customer record is created from the WhatsApp phone if one does not exist.
- Sandbox: only joined testers. Live: Twilio/Meta must approve the WhatsApp sender.
- If replies never arrive, check `TWILIO_WHATSAPP_FROM` and API logs for `WhatsApp send skipped`.
- If bookings never start, the Admin toggle is still off, or the webhook URL is wrong.

---

## Code map

| Piece | Location |
|---|---|
| Webhook | `apps/api/src/whatsapp/whatsapp.controller.ts` |
| Conversation + job create | `apps/api/src/whatsapp/whatsapp.service.ts` |
| Outbound WhatsApp send | `apps/api/src/sms/sms.service.ts` (`sendWhatsApp`) |
| Status replies (matched / no driver) | `apps/api/src/matching/matching.service.ts` |
| Admin toggle | Settings keys `whatsapp_booking_enabled`, `whatsapp_welcome_text` |
