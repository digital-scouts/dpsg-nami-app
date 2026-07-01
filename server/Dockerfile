FROM node:lts-alpine AS base
WORKDIR /app

FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm install

FROM deps AS dev
COPY tsconfig.json ./
COPY src ./src
COPY test ./test
CMD ["npm", "run", "dev"]

FROM deps AS build
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM base AS production
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
COPY --from=deps /app/node_modules ./node_modules
RUN npm prune --omit=dev
COPY --from=build /app/dist ./dist
CMD ["node", "dist/index.js"]