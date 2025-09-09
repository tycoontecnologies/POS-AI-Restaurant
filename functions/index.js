/* eslint-disable max-len */

const functions = require("firebase-functions");
const {setGlobalOptions} = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(
    "sk_test_51QuWRrLEDyNqXPqsjQnS5E8pltmuQc1GthOJ2VKTMoAE7GO2UIZgbglMmHcg6MaGCOlQgtDi3WIsmHsTtR5LY40v00NuIm0HqS",
);

setGlobalOptions({maxInstances: 10});

admin.initializeApp();

// Your Stripe callable function
exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  const {amount} = data;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Amount must be provided and greater than 0",
    );
  }

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: "pkr",
      payment_method_types: ["card"],
    });

    return {
      clientSecret: paymentIntent.client_secret,
    };
  } catch (error) {
    console.error("Stripe Error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});
