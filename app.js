const express = require("express");

const app = express();

const PORT = 3000;

// Home Route
app.get("/", (req, res) => {
    res.send("Hello Zetheta  Project!");
});

// Health Check Route
app.get("/health", (req, res) => {
    res.json({
        status: "UP",
        message: "Application is Healthy"
    });
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});