import { defineConfig } from "@prisma/client";

export default defineConfig({
  schema: "./prisma/schema.prisma",
  seed: "./prisma/seed.js",
});
