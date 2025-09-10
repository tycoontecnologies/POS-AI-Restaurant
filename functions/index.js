const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");
const stripe = require("stripe")(
  "sk_test_51QuWRrLEDyNqXPqsjQnS5E8pltmuQc1GthOJ2VKTMoAE7GO2UIZgbglMmHcg6MaGCOlQgtDi3WIsmHsTtR5LY40v00NuIm0HqS"
);

const app = express();

// Middleware
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST"],
    allowedHeaders: ["Content-Type"],
  })
);
app.use(express.json());

// Create Checkout Session (for web)
app.post("/create-checkout-session", async (req, res) => {
  try {
    console.log("Received request:", req.body); // Add logging

    const {
      amount,
      currency = "pkr",
      planType,
      successUrl,
      cancelUrl,
    } = req.body;

    // Validate input
    if (!amount || amount < 50) {
      console.log("Invalid amount:", amount);
      return res.status(400).json({ error: "Invalid amount" });
    }
    if (!planType) {
      console.log("Missing planType");
      return res.status(400).json({ error: "Plan type is required" });
    }

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: currency.toLowerCase(),
            product_data: {
              name: `${planType} Subscription`,
              description: `${planType} plan subscription`,
            },
            unit_amount: Math.round(amount),
          },
          quantity: 1,
        },
      ],
      mode: "payment",
      success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}&planType=${encodeURIComponent(
        planType
      )}`,
      cancel_url: cancelUrl,
      metadata: {
        planType: planType,
      },
      locale: "auto",
    });

    console.log("Session created:", session.id); // Add logging
    res.json({ url: session.url, sessionId: session.id });
  } catch (error) {
    console.error("Error creating checkout session:", error);
    res.status(500).json({ error: error.message });
  }
});

// Verify Payment Status
app.get("/verify-payment", async (req, res) => {
  try {
    const { session_id } = req.query;

    if (!session_id) {
      return res.status(400).json({ error: "Session ID is required" });
    }

    const session = await stripe.checkout.sessions.retrieve(session_id);

    res.json({
      status: session.payment_status,
      customerEmail: session.customer_details?.email,
      amountTotal: session.amount_total,
      currency: session.currency,
      planType: session.metadata?.planType,
    });
  } catch (error) {
    console.error("Error verifying payment:", error);
    res.status(500).json({ error: error.message });
  }
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "OK", timestamp: new Date().toISOString() });
});

exports.api = functions.https.onRequest(app);
