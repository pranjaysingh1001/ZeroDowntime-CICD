const request = require("supertest");
const app = require("../app");

describe("Health API Contract", () => {

    test("GET /health must follow the API contract", async () => {

        const response = await request(app)
            .get("/health");

        // HTTP status contract
        expect(response.statusCode).toBe(200);

        // Content type contract
        expect(response.headers["content-type"])
            .toMatch(/application\/json/);

        // Response structure contract
        expect(response.body).toHaveProperty("status");
        expect(response.body).toHaveProperty("message");

        // Data type contract
        expect(typeof response.body.status).toBe("string");
        expect(typeof response.body.message).toBe("string");

        // Expected value
        expect(response.body.status).toBe("UP");

    });

});