// ============================================================
// ROYAL PHOTOGRAPHY STUDIOS — Bar Necklace Product Page
// Paste this into the Velo code panel for your bar necklace page.
//
// BEFORE YOU START: In the Wix Editor, note the Product ID of
// your bar necklace product (Wix Stores > Products > click the
// product > the ID is in the browser URL). Replace PRODUCT_ID below.
// ============================================================

import wixStoresFrontend from 'wix-stores-frontend';
import wixWindow from 'wix-window';

// ── CONFIGURE THESE ──────────────────────────────────────────
const PRODUCT_ID = 'PASTE_YOUR_PRODUCT_ID_HERE';
const MAX_CHARS  = 20;   // max characters on a bar necklace
// ─────────────────────────────────────────────────────────────

const FONTS = {
    'Block / Print':    'Arial Black, Impact, sans-serif',
    'Script / Cursive': '"Dancing Script", "Brush Script MT", cursive',
    'Serif (Classic)':  'Georgia, "Times New Roman", serif',
};

const FONT_BUTTONS = {
    'Block / Print':    '#btnBlockPrint',
    'Script / Cursive': '#btnScript',
    'Serif (Classic)':  '#btnSerif',
};

let selectedFont = 'Block / Print';

$w.onReady(() => {

    // ── Character count & live preview ───────────────────────
    $w('#inputCustomText').maxLength = MAX_CHARS;

    $w('#inputCustomText').onInput(() => {
        const val  = $w('#inputCustomText').value;
        const left = MAX_CHARS - val.length;
        $w('#textCharCount').text = `${val.length} / ${MAX_CHARS} characters`;
        $w('#textCharCount').style.color = left <= 3 ? '#c0392b' : '#666666';
        sendPreview();
    });

    // ── Font selection buttons ────────────────────────────────
    Object.keys(FONT_BUTTONS).forEach(fontName => {
        $w(FONT_BUTTONS[fontName]).onClick(() => {
            selectedFont = fontName;
            highlightActiveFont();
            sendPreview();
        });
    });

    // ── Add to Cart ───────────────────────────────────────────
    $w('#btnAddToCart').onClick(async () => {
        const text = $w('#inputCustomText').value.trim();

        if (!text) {
            showError('Please enter the text you want on your bar necklace.');
            return;
        }

        $w('#btnAddToCart').disable();
        $w('#btnAddToCart').label = 'Adding...';
        hideError();

        try {
            await wixStoresFrontend.addProductsToCart([{
                productId: PRODUCT_ID,
                quantity:  1,
                options: {
                    choices: {
                        'Font Style': selectedFont,
                    },
                    customTextFields: [{
                        title: 'Engraving Text',
                        value: text,
                    }],
                },
            }]);

            // Open the cart after adding
            wixWindow.openLightbox('Cart Updated');

        } catch (err) {
            console.error('Add to cart failed:', err);
            showError('Something went wrong. Please try again.');
        } finally {
            $w('#btnAddToCart').enable();
            $w('#btnAddToCart').label = 'Add to Cart';
        }
    });

    // ── Initialise ────────────────────────────────────────────
    highlightActiveFont();
    sendPreview();
});

// ── Helpers ───────────────────────────────────────────────────

function sendPreview() {
    const text = $w('#inputCustomText').value.trim() || 'Your Text Here';
    $w('#htmlPreview').postMessage({
        text,
        font: FONTS[selectedFont],
    });
}

function highlightActiveFont() {
    Object.keys(FONT_BUTTONS).forEach(fontName => {
        const btn = $w(FONT_BUTTONS[fontName]);
        if (fontName === selectedFont) {
            btn.style.backgroundColor = '#8B7355';
            btn.style.color           = '#ffffff';
        } else {
            btn.style.backgroundColor = '#f5f5f5';
            btn.style.color           = '#333333';
        }
    });
}

function showError(msg) {
    $w('#textError').text = msg;
    $w('#textError').show();
}

function hideError() {
    $w('#textError').hide();
}
