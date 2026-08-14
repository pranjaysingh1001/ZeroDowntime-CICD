const express = require("express");

const app = express();

app.get("/", (req, res) => {
    res.send("Hello Zetheta Project! version 2");
});

app.get("/health", (req, res) => {
    res.json({
        status: "UP",
        message: "Application is Healthy"
    });
});

module.exports = app;