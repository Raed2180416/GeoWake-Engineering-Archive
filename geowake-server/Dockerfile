# Keep the image aligned with package.json and CI.  Node 18 can mask runtime
# differences during tests and then fail after deployment.
FROM node:24-slim
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --production
COPY . .
EXPOSE 3000
CMD ["node", "src/server.js"]
