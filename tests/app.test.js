const request = require("supertest");
const app = require("../app");

describe("ZeroDowntime Application Tests", () => {

  test("GET / should return welcome message", async () => {
    const response = await request(app).get("/");

    expect(response.statusCode).toBe(200);
    expect(response.text).toBe("Hello Zetheta Project!");
  });

  test("GET /health should return application health", async () => {
    const response = await request(app).get("/health");

    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("UP");
    expect(response.body.message).toBe("Application is Healthy");
  });

});