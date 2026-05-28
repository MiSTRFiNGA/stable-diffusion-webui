# Bar Necklace Store — Wix Setup Guide
# royaltyphotographystudios.com

---

## What gets built

A store page where customers:
1. Type their custom text (up to 20 characters)
2. Choose a font: Block/Print, Script/Cursive, or Serif
3. See a live gold bar preview updating as they type
4. Click Add to Cart — their text and font choice go into the order

You receive: the order in Wix dashboard (text + font listed) AND an email.

---

## STEP 1 — Create the Bar Necklace product in Wix Stores

1. In the Wix Editor, go to **Add Apps → Wix Stores** (already installed)
2. Go to your **Wix dashboard → Store → Products → + Add Product**
3. Fill in:
   - **Name:** Bar Necklace — Custom Engraving
   - **Price:** your price
   - **Description:** Personalize your bar necklace with up to 20 characters
   - **Images:** add your product photos
4. Under **Product Options**, click **+ Add Option**:
   - Option name: `Font Style`
   - Type: `Buttons`
   - Choices: `Block / Print`, `Script / Cursive`, `Serif (Classic)`
5. Under **Custom Text Fields**, click **+ Add Field**:
   - Field name: `Engraving Text`
   - Required: YES
   - Character limit: 20
6. Save the product and **copy the Product ID from the browser URL**
   (looks like: `3f4e5c6d-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

---

## STEP 2 — Create a new page for the bar necklace

1. In the Wix Editor, click **Pages → + Add Page**
2. Name it: `Bar Necklace`
3. Set the URL to `/bar-necklace`

---

## STEP 3 — Add elements to the page

Add these elements in the Wix Editor and rename their IDs exactly as shown:

| Element type       | ID in Wix          | Label / placeholder         |
|--------------------|--------------------|-----------------------------|
| Text Input         | `inputCustomText`  | "Type your text here..."    |
| Text (small)       | `textCharCount`    | "0 / 20 characters"         |
| Button             | `btnBlockPrint`    | "Block / Print"             |
| Button             | `btnScript`        | "Script / Cursive"          |
| Button             | `btnSerif`         | "Serif (Classic)"           |
| HTML Component     | `htmlPreview`      | (see Step 4)                |
| Button             | `btnAddToCart`     | "Add to Cart"               |
| Text (small, red)  | `textError`        | (hidden by default)         |

To set an element's ID: click the element → click the 3-dot menu → "Set ID"

---

## STEP 4 — Set up the HTML Preview component

1. In Wix Editor, click **Add → Embed → HTML iFrame**
2. Resize it to about 320 × 180 px — this is where the gold bar preview shows
3. Set its ID to `htmlPreview`
4. Click **Edit Code** on the HTML component
5. **Paste the entire contents of `font-preview.html`** into the code box
6. Click **Update**

---

## STEP 5 — Add the Velo page code

1. In the Wix Editor, click **Dev Mode → Turn on Dev Mode**
2. Click the page code panel at the bottom: `Page Code — Bar Necklace`
3. **Delete any existing code**
4. **Paste the entire contents of `bar-necklace-page.js`**
5. Replace `PASTE_YOUR_PRODUCT_ID_HERE` with the Product ID you copied in Step 1
6. Click **Save**

---

## STEP 6 — Set up the email notification

Wix automatically sends you an email when an order comes in. To make sure
it includes the custom text and font:

1. Go to **Wix Dashboard → Notifications → Store Orders**
2. Make sure "New order" notifications are enabled for your email
3. The order email will include the Font Style choice and Engraving Text

For a more detailed notification, go to:
**Wix Dashboard → Automations → + New Automation**
- Trigger: Order is placed
- Action: Send an email to me
- In the email body, insert dynamic fields: Customer name, Order items,
  Custom text fields — this shows the exact text and font the customer chose

---

## STEP 7 — Add the store page to your navigation

1. In Wix Editor → Pages panel
2. Find "Bar Necklace" → click the 3 dots → "Add to Menu"
3. Or drag it to the position you want in your site menu

---

## STEP 8 — Test it

1. Click **Preview** in the Wix Editor
2. Type something in the text box — the gold bar preview should update live
3. Click each font button — the preview font should change
4. Click Add to Cart — the item should appear in your cart with the text
   and font listed under the product

---

## How orders come to you

Every order will show in **Wix Dashboard → Store → Orders** with:
- Product: Bar Necklace — Custom Engraving
- Font Style: [whichever font they chose]
- Engraving Text: [exactly what they typed]

You'll also get an email notification with the same info.

---

## Files in this folder

| File                  | What it is                                      |
|-----------------------|-------------------------------------------------|
| `bar-necklace-page.js`| Paste into Velo page code panel                 |
| `font-preview.html`   | Paste into the HTML iFrame component            |
| `SETUP.md`            | This guide                                      |
