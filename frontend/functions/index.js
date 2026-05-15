require("dotenv").config();
const express = require("express");
const bodyParser = require("body-parser");
const axios = require("axios");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const cors = require("cors");
const { onRequest } = require("firebase-functions/v2/https");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Create an Express app
const app = express();

app.use(bodyParser.json());
app.use(cors({ origin: true }));

const GMAIL_EMAIL = process.env.GMAIL_EMAIL;
const GMAIL_PASSWORD = process.env.GMAIL_PASSWORD;

let emailTransporter;

app.post("/sendCustomEmail", async (req, res) => {
  const { to, subject, body, attachmentUrl } = req.body;

  if (!to || !subject || !body) {
    return res.status(400).send({ error: "Missing required fields: to, subject, body" });
  }

  try {
    if (!emailTransporter) {
      if (!GMAIL_EMAIL || !GMAIL_PASSWORD) {
        console.error("Gmail email or password not set in environment variables.");
        return res.status(500).send({ error: "Email service not configured." });
      }

      emailTransporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: GMAIL_EMAIL,
          pass: GMAIL_PASSWORD,
        },
      });
    }

    const emailAttachments = [];

    if (attachmentUrl) {
      console.log(`Downloading attachment from: ${attachmentUrl}`);
      try {
        const response = await axios.get(attachmentUrl, {
          responseType: "arraybuffer",
        });
        const buffer = Buffer.from(response.data, "binary");

        emailAttachments.push({
          filename: "Report.pdf",
          content: buffer,
          contentType: "application/pdf",
        });
      } catch (error) {
        console.error("Failed to download attachment:", error);
        return res.status(500).send({ error: "Failed to download attachment." });
      }
    }

    const mailOptions = {
      from: `"Dankie App" <${GMAIL_EMAIL}>`,
      to: to,
      subject: subject,
      html: `<p>${body.replace(/\n/g, "<br>")}</p>`,
      attachments: emailAttachments,
    };

    await emailTransporter.sendMail(mailOptions);
    console.log(`Email successfully sent to ${to}`);
    return res.status(200).send({ success: true });
  } catch (error) {
    console.error("Error sending email:", error);
    return res.status(500).send({ error: "Failed to send email." });
  }
});

// =========================================================================
// 6. EXPORT THE 'api' FUNCTION
// =========================================================================
exports.api = onRequest(
  {
    timeoutSeconds: 120, 
    memory: "1GiB",
  },
  app
);